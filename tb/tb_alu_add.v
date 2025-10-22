`timescale 1ns/1ps
`include "decode.vh"
module alu_tb_add;
    reg [31:0] a,b;
    wire [31:0] y;
    wire zero;
    reg [3:0] op = `ALU_ADD;
    alu DUT(.a(a), .b(b), .op(op), .y(y), .zero(zero));
    integer i, failures;
    reg [31:0] expected;
    reg [31:0] dir_a [0:19];
    reg [31:0] dir_b [0:19];
    initial begin
        failures = 0;
        // directed vectors (same as before)
        dir_a[0]=32'h00000000; dir_b[0]=32'h00000000;
        dir_a[1]=32'h00000001; dir_b[1]=32'h00000001;
        dir_a[2]=32'h7FFFFFFF; dir_b[2]=32'h7FFFFFFF;
        dir_a[3]=32'h80000000; dir_b[3]=32'hFFFFFFFF;
        dir_a[4]=32'hFFFFFFFF; dir_b[4]=32'h00000001;
        dir_a[5]=32'hFFFF0000; dir_b[5]=32'h00010000;
        dir_a[6]=32'h00000010; dir_b[6]=32'h00000020;
        dir_a[7]=32'h0000001F; dir_b[7]=32'h80000000;
        dir_a[8]=32'h00000005; dir_b[8]=32'h00000000;
        dir_a[9]=32'h80000000; dir_b[9]=32'h80000000;
        dir_a[10]=32'hFFFFFFFE; dir_b[10]=32'h00000002;
        dir_a[11]=32'h00000003; dir_b[11]=32'hFFFFFFFF;
        dir_a[12]=32'h00001234; dir_b[12]=32'h00005678;
        dir_a[13]=32'h89ABCDEF; dir_b[13]=32'h13579BDF;
        dir_a[14]=32'h80000001; dir_b[14]=32'h00000002;
        dir_a[15]=32'h7FFFFFFE; dir_b[15]=32'h00000002;
        dir_a[16]=32'h00000020; dir_b[16]=32'h00000005;
        dir_a[17]=32'h00000000; dir_b[17]=32'hFFFFFFFF;
        dir_a[18]=32'hDEADBEEF; dir_b[18]=32'hCAFEBABE;
        dir_a[19]=32'h0000FFFF; dir_b[19]=32'h00FF00FF;
        // directed test
        for (i=0;i<20;i=i+1) begin
            a = dir_a[i]; b = dir_b[i]; #1;
            expected = a + b;
            #1;
            if (y !== expected) begin $display("FAIL ADD directed a=%h b=%h exp=%h got=%h", a,b,expected,y); failures = failures+1; $finish; end
        end
        // random tests
        for (i=0;i<2000;i=i+1) begin
            a = $random; b = $random; #1;
            expected = a + b; #1;
            if (y !== expected) begin $display("FAIL ADD random a=%h b=%h exp=%h got=%h", a,b,expected,y); failures = failures+1; $finish; end
        end
        if (failures==0) $display("=================== ADD tests passed ===================");
        $finish;
    end
endmodule
