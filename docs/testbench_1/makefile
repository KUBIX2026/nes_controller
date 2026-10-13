# Nombre del proyecto principal y archivos de sintesis para hardware
PROJ = nes_uart_top
SRCS = nes_uart_top.v nes_controller.v
LPF  = colorlight.lpf

# Archivos de simulación
TB      = tb_nes_controller.v
SIM_OUT = sim_nes_controller
VCD_OUT = tb_nes_controller.vcd

# Configuración específica para Colorlight i9 (Lattice ECP5 LFE5U-45F)
DEVICE  = 45k
PACKAGE = CABGA381

# Herramientas de la toolchain
YOSYS   = yosys
NEXTPNR = nextpnr-ecp5
ECPPACK = ecppack
OFL     = openFPGALoader
IVERILOG= iverilog
VVP     = vvp
GTKWAVE = gtkwave

# Programador (ajusta a ft232 si no usas cmsisdap)
PROGRAMMER = cmsisdap

all: $(PROJ).bit

# --- REGLAS DE SÍNTESIS Y HARDWARE ---
$(PROJ).json: $(SRCS)
	$(YOSYS) -p "synth_ecp5 -top $(PROJ) -json $@" $(SRCS)

$(PROJ)_out.config: $(PROJ).json $(LPF)
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $(PROJ).json --lpf $(LPF) --textcfg $@

$(PROJ).bit: $(PROJ)_out.config
	$(ECPPACK) $< $@

prog: $(PROJ).bit
	$(OFL) -c $(PROGRAMMER) $<

flash: $(PROJ).bit
	$(OFL) -c $(PROGRAMMER) -f $<

# --- REGLAS DE SIMULACIÓN Y GTKWAVE ---
sim: $(SRCS) $(TB)
	$(IVERILOG) -o $(SIM_OUT) $(TB) nes_controller.v
	$(VVP) $(SIM_OUT)

wave: sim
	$(GTKWAVE) $(VCD_OUT) &

clean:
	rm -f *.json *.config *.bit $(SIM_OUT) *.vcd

.PHONY: all prog flash sim wave clean