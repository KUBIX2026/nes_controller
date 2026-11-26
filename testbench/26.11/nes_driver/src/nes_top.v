// ============================================================================
// nes_top.v  -  Top para la Tang Nano 9K (GW1NR-9)
//
//   clk          : reloj de 27 MHz (pin 52)
//   s1           : RESET (boton S1, activo en bajo: presionado = 0 = rst_n = 0)
//   nes_latch    : -> pin LATCH del control
//   nes_clock    : -> pin CLOCK del control
//   nes_data     : <- pin DATA  del control
//   buttons[7:0] : estado de los 8 botones del control (1 = presionado),
//                  se actualiza una vez por lectura, cuando ready = 1.
//
// Orden (igual al diagrama de flujo: botones[0] es el primer bit leido):
//   [0]=A [1]=B [2]=Select [3]=Start [4]=Up [5]=Down [6]=Left [7]=Right
//
// ATENCION: el control NES trabaja a 5 V; los pines de la Tang Nano 9K son de
// 3.3 V. Usa un adaptador de nivel (o al menos un divisor resistivo en DATA).
// ============================================================================
module nes_top #(
    parameter CLK_HZ    = 27_000_000,
    parameter PERIOD_US = 16_600
) (
    input  wire       clk,
    input  wire       s1,
    output wire       nes_latch,
    output wire       nes_clock,
    input  wire       nes_data,
    output wire [7:0] buttons
);

    // ---- Sincronizadores de entradas asincronas ---------------------------
    // rst_sync arranca en 0 -> reset de encendido automatico (2 ciclos).
    reg [1:0] rst_sync = 2'b00;
    reg [1:0] dat_sync = 2'b11;

    always @(posedge clk) begin
        rst_sync <= {rst_sync[0], s1};
        dat_sync <= {dat_sync[0], nes_data};
    end

    wire rst_n = rst;
    wire data  = dat_sync[1];

    // ---- Disparo periodico de lectura -------------------------------------
    wire start_read;

    poll_timer #(.CLK_HZ(CLK_HZ), .PERIOD_US(PERIOD_US)) u_poll (
        .clk_in     (clk),
        .rst_n      (rst_n),
        .start_read (start_read)
    );

    // ---- Driver NES ---------------------------------------------------------
    wire       ready;
    wire [7:0] buttons_drv;

    nes_driver #(.CLK_HZ(CLK_HZ)) u_driver (
        .clk_in     (clk),
        .rst_n      (rst_n),
        .start_read (start_read),
        .data       (data),
        .latch      (nes_latch),
        .clock      (nes_clock),
        .ready      (ready),
        .buttons    (buttons_drv)
    );

    // ---- Captura del byte cuando ready = 1 --------------------------------
    reg [7:0] buttons_q;
    always @(posedge clk) begin
        if (!rst_n)      buttons_q <= 8'd0;
        else if (ready)  buttons_q <= buttons_drv;
    end

    assign buttons = buttons_q;

endmodule
