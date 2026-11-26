// ============================================================================
// nes_driver.v  -  "Modulo Driver NES - internamente"
//
// Interconexion de los 4 bloques del diagrama de bloques:
//
//     nes_fsm  <-->  nes_timer          (time_rst / time_done_clk / time_done_latch)
//     nes_fsm  <-->  nes_bit_counter    (cnt_en / bits_done)
//     nes_fsm  ---> nes_shift_reg       (shift_en)  + data -> buttons[7:0]
//
// Puertos externos: clk_in, rst_n, start_read, data  ->  latch, clock, ready,
//                   buttons[7:0]
//
// Nota: latch / clock / ready salen por un registro (1 ciclo de retardo,
// igual para las tres) para que los pines externos no tengan glitches
// provenientes de la decodificacion combinacional de estados. Los tiempos
// (12 us / 6 us) no cambian.
// ============================================================================
module nes_driver #(
    parameter CLK_HZ = 27_000_000
) (
    input  wire       clk_in,
    input  wire       rst_n,
    input  wire       start_read,
    input  wire       data,        // Linea serial del control (ya sincronizada)

    output wire       latch,
    output wire       clock,
    output wire       ready,
    output wire [7:0] buttons
);

    // Senales internas entre bloques
    wire time_rst, time_done_clk, time_done_latch;
    wire shift_en, cnt_en, bits_done;
    wire latch_c, clock_c, ready_c;

    nes_fsm u_fsm (
        .clk_in          (clk_in),
        .rst_n           (rst_n),
        .start_read      (start_read),
        .time_done_clk   (time_done_clk),
        .time_done_latch (time_done_latch),
        .bits_done       (bits_done),
        .latch           (latch_c),
        .clock           (clock_c),
        .ready           (ready_c),
        .time_rst        (time_rst),
        .shift_en        (shift_en),
        .cnt_en          (cnt_en)
    );

    nes_timer #(.CLK_HZ(CLK_HZ)) u_timer (
        .clk_in          (clk_in),
        .rst_n           (rst_n),
        .time_rst        (time_rst),
        .time_done_clk   (time_done_clk),
        .time_done_latch (time_done_latch)
    );

    nes_bit_counter u_bit_counter (
        .clk_in    (clk_in),
        .rst_n     (rst_n),
        .cnt_en    (cnt_en),
        .bits_done (bits_done)
    );

    nes_shift_reg u_shift_reg (
        .clk_in   (clk_in),
        .rst_n    (rst_n),
        .shift_en (shift_en),
        .data     (data),
        .buttons  (buttons)
    );

    // Registro de salida (anti-glitch)
    reg latch_q, clock_q, ready_q;
    always @(posedge clk_in) begin
        if (!rst_n) begin
            latch_q <= 1'b0;
            clock_q <= 1'b0;
            ready_q <= 1'b0;
        end else begin
            latch_q <= latch_c;
            clock_q <= clock_c;
            ready_q <= ready_c;
        end
    end

    assign latch = latch_q;
    assign clock = clock_q;
    assign ready = ready_q;

endmodule
