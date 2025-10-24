// ... full RTL as provided above ...
`timescale 1ns/1ps
`include "decode.vh"

module simplerisc_top(
    input  wire clk,
    input  wire rstn,
    output wire[31:0] alu_debug
);
    // ==== Program Counter ====
    reg [31:0] pc, pc_next;

    // ==== Fetch ====
    wire [31:0] instr;
    imem U_IMEM(.addr(pc[31:2]), .instr(instr));

    // ==== Decode fields ====
    wire [4:0]  op   = `OP(instr);
    wire        Ibit = `Ibit(instr);
    wire [3:0]  rd   = `RD(instr);
    wire [3:0]  rs1  = `RS1(instr);
    wire [3:0]  rs2  = `RS2(instr);
    wire [17:0] imm18= `IMM18(instr);
    wire [26:0] off27= `BR_OFFSET27(instr);

    // ==== Immediate & branch target expanders ====
    wire [31:0] immx;
    immu U_IMMU(.imm18(imm18), .immx(immx));

    wire [31:0] br_target_pc;
    branch_target U_BRT(.off27(off27), .pc(pc), .target(br_target_pc));
    
    wire [3:0]  wb_rd_final  = take_call ? `RA : rd;
    wire        wb_we_final  = wb_en | take_call; // CALL writes link

    // ==== Register file ====
    wire [31:0] rs1_rdata, rs2_rdata, wb_data;
    regfile U_RF(
        .clk(clk),
        .we(wb_we_final),
        .rs1(rs1),
        .rs2(rs2),
        .rd (wb_rd_final),
        .wdata(wb_data),
        .rdata1(rs1_rdata),
        .rdata2(rs2_rdata)
    );

    // ==== Control ====
    wire [3:0] alu_op;
    wire use_imm, mem_read, mem_write, wb_en, wb_from_mem;
    wire is_branch, is_beq, is_bgt, is_b, is_call, is_ret, is_cmp, is_mov, is_not, is_ld, is_st;

    control_unit U_CTRL(
        .op(op), .Ibit(Ibit),
        .alu_op(alu_op), .use_imm(use_imm),
        .mem_read(mem_read), .mem_write(mem_write),
        .wb_en(wb_en), .wb_from_mem(wb_from_mem),
        .is_branch(is_branch), .is_beq(is_beq), .is_bgt(is_bgt), .is_b(is_b),
        .is_call(is_call), .is_ret(is_ret), .is_cmp(is_cmp), .is_mov(is_mov),
        .is_not(is_not), .is_ld(is_ld), .is_st(is_st)
    );

    // ==== Operand B mux ====
    wire [31:0] opB = use_imm ? immx : rs2_rdata;

    // ==== ALU ====
    wire [31:0] alu_y;
    wire        alu_zero;
    alu U_ALU(.a((is_not|is_mov) ? 32'd0 : rs1_rdata), .b(opB), .op(alu_op), .y(alu_y), .zero(alu_zero));

    // ==== Flags (from CMP only) ====
    reg flag_E, flag_GT;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            flag_E  <= 1'b0;
            flag_GT <= 1'b0;
        end else if (is_cmp) begin
            // Compare rs1 vs (rs2/imm)
            flag_E  <= (rs1_rdata == opB);
            flag_GT <= ($signed(rs1_rdata) > $signed(opB));
        end
    end

    // ==== Data memory ====
    // Address for ld/st is rs1 + immx (ALU already does ADD)
    wire [31:0] dmem_rdata;
    dmem U_DMEM(
        .clk(clk),
        .re(mem_read),
        .we(mem_write),
        .addr(alu_y),
        .wdata( store_wdata ),
        .rdata(dmem_rdata)
    );

    // For ST, source is encoded in 'rd' field per spec: st rd, imm[rs1]
    wire [31:0] store_wdata = U_RF.rf[rd]; // access internal array; alternatively add a 3rd read port
    // If your simulator disallows hierarchical access, change regfile to expose a 3rd read port.

    // ==== Writeback mux ====
    assign wb_data = wb_from_mem ? dmem_rdata : alu_y;

    // ==== Branch decision ====
    wire take_beq = is_beq & flag_E;
    wire take_bgt = is_bgt & flag_GT;
    wire take_b   = is_b;
    wire take_call= is_call;
    wire take_ret = is_ret;

    wire take_any = take_beq | take_bgt | take_b | take_call | take_ret;

    // ==== WB routing & special CALL write to RA ====
    // Normal destination is 'rd' (for ALU/LD/MOV/NOT). For CALL, dest is RA (r15) with (PC+4).
    
    wire [31:0] link_value   = pc + 32'd4;
    wire [31:0] wb_data_pre  = wb_from_mem ? dmem_rdata : alu_y;
    assign wb_data      = take_call ? link_value : wb_data_pre;

    // ==== Next PC ====
    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] ret_target = U_RF.rf[`RA]; // ra
    always @(*) begin
        if (take_any) begin
            if (take_ret)      pc_next = ret_target;
            else               pc_next = br_target_pc; // b/beq/bgt/call use branchTarget(pc+sext(off<<2))
        end else begin
            pc_next = pc_plus4;
        end
    end

    // ==== State updates ====
    always @(posedge clk or negedge rstn) begin
        if (!rstn) pc <= 32'd0;
        else       pc <= pc_next;
    end
    assign alu_debug=alu_y;
endmodule
