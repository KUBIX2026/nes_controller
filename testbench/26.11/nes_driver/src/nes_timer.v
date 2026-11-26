// ============================================================================
// nes_timer.v  -  Bloque "Timer" del diagrama de bloques
//
//   Entradas : clk_in, rst_n, time_rst
//   Salidas  : time_done_clk   (6 us)
//              time_done_latch (12 us)
//
// Contador libre con auto-recarga cada 12 us (mientras time_rst = 0).
// Las salidas son pulsos de 1 ciclo de reloj:
//   time_done_latch -> cnt == 12us-1
//   time_done_clk   -> cnt == 6us-1  o  cnt == 12us-1   (cada 6 us)
//
// Por que auto-recarga: en la FSM, CLK_LOW se alcanza desde LATCH y desde
// CLK_HIGH, estados donde time_rst = 0 (el timer NO se reinicia). Como el
// timer sigue contando, la siguiente marca de 6 us llega exactamente 6 us
// despues, y CLK_LOW siempre dura 6 us completos.
// ============================================================================
module nes_timer #(
    parameter CLK_HZ = 27_000_000,   // Reloj de la Tang Nano 9K
    parameter CNT_W  = 12            // Soporta hasta ~341 MHz
) (
    input  wire clk_in,
    input  wire rst_n,
    input  wire time_rst,
    output wire time_done_clk,
    output wire time_done_latch
);

    localparam integer T6  = (CLK_HZ / 1_000_000) * 6;   // ciclos en 6 us
    localparam integer T12 = T6 * 2;                      // ciclos en 12 us

    reg [CNT_W-1:0] cnt;

    always @(posedge clk_in) begin
        if (!rst_n || time_rst)
            cnt <= {CNT_W{1'b0}};
        else if (cnt == T12 - 1)
            cnt <= {CNT_W{1'b0}};
        else
            cnt <= cnt + 1'b1;
    end

    assign time_done_latch = (cnt == T12 - 1);
    assign time_done_clk   = (cnt == T6  - 1) || (cnt == T12 - 1);

endmodule
