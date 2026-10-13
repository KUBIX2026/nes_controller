`timescale 1ns / 1ps

module nes_controller #(
    // La Colorlight i9 suele usar un reloj de 25 MHz. 
    // Si usas un PLL para otra frecuencia, cámbialo aquí.
    parameter CLK_FREQ = 25000000, 
    parameter REFRESH_RATE = 60    // Leer el control a 60 Hz (60 veces por segundo)
)(
    input  wire       clk,        // Reloj del sistema (FPGA)
    input  wire       rst_n,      // Reset activo en bajo
    input  wire       nes_data,   // Señal de datos que viene del control
    output reg        nes_latch,  // Señal de Latch hacia el control
    output reg        nes_clk,    // Señal de Reloj hacia el control
    output reg  [7:0] buttons     // Estado de los botones (1 = Presionado, 0 = Suelto)
);

    // Cálculos de ciclos de reloj para los tiempos requeridos por el NES
    // Se calcula automáticamente según CLK_FREQ para evitar problemas de timing.
    localparam CYCLES_PER_REFRESH = CLK_FREQ / REFRESH_RATE;
    localparam CYCLES_12US        = (CLK_FREQ * 12) / 1000000; // 12 microsegundos
    localparam CYCLES_6US         = (CLK_FREQ *  6) / 1000000; // 6 microsegundos

    // Registros internos
    reg [31:0] timer;
    reg [3:0]  bit_count;
    reg [7:0]  shift_reg;

    // Estados de la máquina de estados
    localparam IDLE      = 3'd0;
    localparam LATCH     = 3'd1;
    localparam WAIT      = 3'd2;
    localparam CLK_HIGH  = 3'd3;
    localparam CLK_LOW   = 3'd4;
    localparam DONE      = 3'd5;

    reg [2:0] state = IDLE;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            timer     <= 0;
            bit_count <= 0;
            nes_latch <= 0;
            nes_clk   <= 0;
            buttons   <= 8'b0;
            shift_reg <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    nes_latch <= 0;
                    nes_clk   <= 0;
                    if (timer >= CYCLES_PER_REFRESH) begin
                        timer     <= 0;
                        state     <= LATCH;
                        nes_latch <= 1; // Inicia el pulso de Latch
                    end else begin
                        timer <= timer + 1;
                    end
                end
                
                LATCH: begin
                    // Mantener el Latch en alto por ~12 us
                    if (timer >= CYCLES_12US) begin
                        timer     <= 0;
                        nes_latch <= 0;
                        state     <= WAIT;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                
                WAIT: begin
                    // Esperar 6 us después del Latch para leer el botón A
                    if (timer >= CYCLES_6US) begin
                        timer        <= 0;
                        // El NES envía 0 cuando está presionado. Invertimos con '~' 
                        // para que la salida final sea 1 = Presionado.
                        shift_reg[0] <= ~nes_data; 
                        bit_count    <= 1;
                        state        <= CLK_HIGH;
                        nes_clk      <= 1;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                
                CLK_HIGH: begin
                    // Mantener Clock en alto por 6 us
                    if (timer >= CYCLES_6US) begin
                        timer   <= 0;
                        nes_clk <= 0;
                        state   <= CLK_LOW;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                
                CLK_LOW: begin
                    // Mantener Clock en bajo por 6 us y leer el siguiente botón
                    if (timer >= CYCLES_6US) begin
                        timer <= 0;
                        shift_reg[bit_count] <= ~nes_data;
                        
                        if (bit_count == 7) begin
                            state <= DONE; // Ya leímos los 8 botones
                        end else begin
                            bit_count <= bit_count + 1;
                            state     <= CLK_HIGH;
                            nes_clk   <= 1; // Siguiente pulso de reloj
                        end
                    end else begin
                        timer <= timer + 1;
                    end
                end
                
                DONE: begin
                    buttons <= shift_reg; // Actualizar la salida de los botones al mismo tiempo
                    state   <= IDLE;
                    timer   <= 0; // Reiniciar contador para esperar el siguiente frame (60Hz)
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule