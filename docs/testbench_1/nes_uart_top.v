`timescale 1ns / 1ps

module nes_uart_top (
    input  wire clk,
    input  wire rst_n,
    input  wire nes_data,
    output wire nes_latch,
    output wire nes_clk,
    output wire uart_tx_pin,
    output wire [7:0] buttons // Dejamos los botones como salida para que Yosys no los optimice
);

    // 1. Instanciamos tu control de NES original (Configurado para 25 MHz)
    nes_controller #(
        .CLK_FREQ(25000000), 
        .REFRESH_RATE(60)
    ) nes (
        .clk(clk),
        .rst_n(rst_n),
        .nes_data(nes_data),
        .nes_latch(nes_latch),
        .nes_clk(nes_clk),
        .buttons(buttons)
    );

    // 2. Temporizador para enviar texto a 10 Hz (25,000,000 / 10)
    reg [23:0] tx_timer = 0;
    wire send_tick = (tx_timer == 2500000 - 1);
    
    always @(posedge clk) begin
        if (send_tick) tx_timer <= 0;
        else tx_timer <= tx_timer + 1;
    end

    // 3. Máquina de estados para formatear el texto
    reg [3:0] state_uart = 0;
    reg [3:0] byte_idx = 0;
    reg send_uart = 0;
    reg [7:0] uart_data = 0;
    wire uart_busy;

    always @(posedge clk) begin
        case(state_uart)
            0: if (send_tick) begin state_uart <= 1; byte_idx <= 1; end
            1: begin
                send_uart <= 0;
                // Si el botón está presionado (1), envía su letra. Si no, un guión.
                case (byte_idx)
                    1: uart_data <= buttons[0] ? "A" : "-";
                    2: uart_data <= buttons[1] ? "B" : "-";
                    3: uart_data <= buttons[2] ? "S" : "-"; // Select
                    4: uart_data <= buttons[3] ? "T" : "-"; // Start
                    5: uart_data <= buttons[4] ? "U" : "-"; // Up
                    6: uart_data <= buttons[5] ? "D" : "-"; // Down
                    7: uart_data <= buttons[6] ? "L" : "-"; // Left
                    8: uart_data <= buttons[7] ? "R" : "-"; // Right
                    9: uart_data <= 8'h0D; // \r (Retorno de carro)
                    10: uart_data <= 8'h0A; // \n (Nueva línea)
                    default: uart_data <= 8'h0A;
                endcase
                state_uart <= 2;
            end
            2: begin
                send_uart <= 1;
                state_uart <= 3;
            end
            3: begin
                send_uart <= 0;
                if (uart_busy) state_uart <= 4;
            end
            4: begin
                if (!uart_busy) begin 
                    if (byte_idx == 10) state_uart <= 0;
                    else begin
                        byte_idx <= byte_idx + 1;
                        state_uart <= 1;
                    end
                end
            end
        endcase
    end

    // 4. Módulo Transmisor Serial (115200 baudios a 25MHz -> 25M / 115200 = 217)
    uart_tx #(.CLKS_PER_BIT(217)) tx_inst (
        .clk(clk),
        .send(send_uart),
        .data(uart_data),
        .tx(uart_tx_pin),
        .busy(uart_busy)
    );

endmodule

// Sub-módulo transmisor UART
module uart_tx #(parameter CLKS_PER_BIT = 217) (
    input wire clk,
    input wire send,
    input wire [7:0] data,
    output wire tx,
    output reg busy
);
    reg [3:0] bit_idx = 0;
    reg [15:0] clk_cnt = 0;
    reg [9:0] shift_reg = 10'b1111111111;

    assign tx = busy ? shift_reg[0] : 1'b1;
    initial busy = 0;

    always @(posedge clk) begin
        if (send && !busy) begin
            shift_reg <= {1'b1, data, 1'b0}; 
            busy <= 1;
            bit_idx <= 0;
            clk_cnt <= 0;
        end else if (busy) begin
            if (clk_cnt == CLKS_PER_BIT - 1) begin
                clk_cnt <= 0;
                if (bit_idx == 9) busy <= 0;
                else begin
                    shift_reg <= {1'b1, shift_reg[9:1]};
                    bit_idx <= bit_idx + 1;
                end
            end else clk_cnt <= clk_cnt + 1;
        end
    end
endmodule