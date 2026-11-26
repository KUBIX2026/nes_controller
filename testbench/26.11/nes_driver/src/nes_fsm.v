// ============================================================================
// nes_fsm.v  -  Bloque "Maquina de Estados Finitos"
//
//   Entradas : clk_in, rst_n, start_read,
//              time_done_clk, time_done_latch, bits_done
//   Salidas  : latch, clock, ready          (hacia el control NES / usuario)
//              time_rst, shift_en, cnt_en   (hacia Timer / Registro / Contador)
//
// Salidas tipo Moore, exactamente como la tabla de cada estado del diagrama:
//
//   Estado     latch clock ready time_rst shift_en cnt_en
//   RESET        0     0     0      1        0       0
//   START        0     0     0      1        0       0
//   LATCH        1     0     0      0        0       0
//   CLK_LOW      0     0     0      0        0       0
//   READ         0     0     0      1        1       1
//   CLK_HIGH     0     1     0      0        0       0
//   READY        0     0     1      1        0       0
//
// Transiciones:
//   RESET    --------------------------> START
//   START    --start_read=1-------------> LATCH      (start_read=0: se queda)
//   LATCH    --time_done (12 us)--------> CLK_LOW
//   CLK_LOW  --time_done (6 us)---------> READ
//   READ     --------------------------> CLK_HIGH
//   CLK_HIGH --time_done (6 us), bits_done=0 --> CLK_LOW   (lazo de lectura)
//   CLK_HIGH --time_done (6 us), bits_done=1 --> READY
//   READY    --------------------------> START
//   cualquier estado, rst_n = 0 --------> RESET
// ============================================================================
module nes_fsm (
    input  wire clk_in,
    input  wire rst_n,
    input  wire start_read,
    input  wire time_done_clk,
    input  wire time_done_latch,
    input  wire bits_done,

    output reg  latch,
    output reg  clock,
    output reg  ready,
    output reg  time_rst,
    output reg  shift_en,
    output reg  cnt_en
);

    localparam [2:0] S_RESET    = 3'd0,
                     S_START    = 3'd1,
                     S_LATCH    = 3'd2,
                     S_CLK_LOW  = 3'd3,
                     S_READ     = 3'd4,
                     S_CLK_HIGH = 3'd5,
                     S_READY    = 3'd6;

    reg [2:0] state, next_state;

    // ---- Registro de estado ------------------------------------------------
    always @(posedge clk_in) begin
        if (!rst_n) state <= S_RESET;
        else        state <= next_state;
    end

    // ---- Logica de siguiente estado ---------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_RESET:    next_state = S_START;

            S_START:    if (start_read)       next_state = S_LATCH;

            S_LATCH:    if (time_done_latch)  next_state = S_CLK_LOW;

            S_CLK_LOW:  if (time_done_clk)    next_state = S_READ;

            S_READ:     next_state = S_CLK_HIGH;

            S_CLK_HIGH: if (time_done_clk)
                            next_state = bits_done ? S_READY : S_CLK_LOW;

            S_READY:    next_state = S_START;

            default:    next_state = S_RESET;
        endcase
    end

    // ---- Salidas (Moore) ---------------------------------------------------
    always @(*) begin
        latch    = 1'b0;
        clock    = 1'b0;
        ready    = 1'b0;
        time_rst = 1'b0;
        shift_en = 1'b0;
        cnt_en   = 1'b0;
        case (state)
            S_RESET:    time_rst = 1'b1;
            S_START:    time_rst = 1'b1;
            S_LATCH:    latch    = 1'b1;
            S_CLK_LOW:  ;                               // todo en 0
            S_READ:     begin time_rst = 1'b1; shift_en = 1'b1; cnt_en = 1'b1; end
            S_CLK_HIGH: clock    = 1'b1;
            S_READY:    begin ready = 1'b1; time_rst = 1'b1; end
            default:    time_rst = 1'b1;
        endcase
    end

endmodule
