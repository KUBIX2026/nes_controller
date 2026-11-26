// ============================================================================
// poll_timer.v  -  Generador de start_read (solo para el top de la FPGA)
//
// Del diagrama de flujo: "Esperar 16.6 ms" entre lecturas (~60 Hz, un cuadro
// de video NTSC). Entrega un pulso de 1 ciclo en start_read cada PERIOD_US.
// No forma parte del driver; es lo que lo dispara en la placa.
// ============================================================================
module poll_timer #(
    parameter CLK_HZ    = 27_000_000,
    parameter PERIOD_US = 16_600            // 16.6 ms
) (
    input  wire clk_in,
    input  wire rst_n,
    output reg  start_read
);

    localparam integer PERIOD_CYCLES = (CLK_HZ / 1_000_000) * PERIOD_US;

    reg [23:0] cnt;                          // 27*16600 = 448 200 < 2^24

    always @(posedge clk_in) begin
        if (!rst_n) begin
            cnt        <= 24'd0;
            start_read <= 1'b0;
        end else if (cnt == PERIOD_CYCLES - 1) begin
            cnt        <= 24'd0;
            start_read <= 1'b1;
        end else begin
            cnt        <= cnt + 24'd1;
            start_read <= 1'b0;
        end
    end

endmodule
