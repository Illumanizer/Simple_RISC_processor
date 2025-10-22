TOP=tb/tb_simplerisc.v
RTL=rtl/simplerisc_top.v rtl/decode.vh rtl/immu.v rtl/alu.v rtl/regfile.v rtl/control_unit.v rtl/imem.v rtl/dmem.v
TB=tb/tb_simplerisc.v
VVP=sim.vvp

all: run

test_add:
	iverilog -g2012 -I rtl -o build/tb_alu_add.vvp tb/tb_alu_add.v rtl/bk_adder32.v rtl/alu.v rtl/mul_tree32.v rtl/div_restoring32.v
	vvp build/tb_alu_add.vvp

test_sub:
	iverilog -g2012 -I rtl -o build/tb_alu_sub.vvp tb/tb_alu_sub.v rtl/bk_adder32.v rtl/alu.v rtl/mul_tree32.v rtl/div_restoring32.v
	vvp build/tb_alu_sub.vvp

test_logic:
	iverilog -g2012 -I rtl -o build/tb_alu_logic.vvp tb/tb_alu_logic.v rtl/bk_adder32.v rtl/alu.v rtl/mul_tree32.v rtl/div_restoring32.v
	vvp build/tb_alu_logic.vvp

test_shift:
	iverilog -g2012 -I rtl -o build/tb_alu_shift.vvp tb/tb_alu_shift.v rtl/bk_adder32.v rtl/alu.v rtl/mul_tree32.v rtl/div_restoring32.v
	vvp build/tb_alu_shift.vvp

test_mul:
	iverilog -g2012 -I rtl -o build/tb_alu_mul.vvp tb/tb_alu_mul.v rtl/bk_adder32.v rtl/alu.v rtl/mul_tree32.v rtl/div_restoring32.v
	vvp build/tb_alu_mul.vvp

test_div:
	iverilog -g2012 -I rtl -o build/tb_alu_divmod.vvp tb/tb_alu_divmod.v rtl/bk_adder32.v rtl/alu.v rtl/mul_tree32.v rtl/div_restoring32.v
	vvp build/tb_alu_divmod.vvp

test_all: test_add test_sub test_logic test_shift test_mul test_div
	@echo "✅ All ALU tests completed successfully."

build:
	iverilog -g2012 -o $(VVP) $(TB) $(RTL)

run: build
	vvp $(VVP)

wave: run
	@echo "Open wave.vcd in GTKWave"

clean:
	rm -f $(VVP) wave.vcd
