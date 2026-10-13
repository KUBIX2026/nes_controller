`timescale 1ns / 1ps

module uart_test (
    input  wire clk,
    output wire uart_tx_pin,
    output reg  test_led   // Señal visual de que la placa está funcionando
);

    // Divisor para 115200 baudios a 25MHz
    parameter CLKS_PER_BIT = 217;

    reg [24:0] timer = 0;
    reg [2:0]  state = 0;
    reg [2:0]  char_idx = 0;
    reg send = 0;
    reg [7:0] data = 0;
    wire busy;

    initial test_led = 0;

    // Máquina de estados que envía "HOLA\r\n" cada 1 segundo exacto
    always @(posedge clk) begin
        case (state)
            0: begin
                send <= 0;
                if (timer == 25000000 - 1) begin // Cuenta hasta 25 millones (1 segundo)
                    timer <= 0;
                    state <= 1;
                    char_idx <= 0;
                    test_led <= ~test_led; // Invierte el estado del pin (parpadeo)
                end else begin
                    timer <= timer + 1;
                end
            end
            1: begin
                case (char_idx)
                    0: data <= "H";
                    1: data <= "O";
                    2: data <= "L";
                    3: data <= "A";
                    4: data <= 8'h0D; // Retorno de carro (\r)
                    5: data <= 8'h0A; // Nueva línea (\n)
                endcase
                state <= 2;
            end
            2: begin
                send <= 1; // Dispara el envío
                state <= 3;
            end
            3: begin
                send <= 0;
                if (busy) state <= 4;
            end
            4: begin
                if (!busy) begin
                    if (char_idx == 5) state <= 0; // Si ya envió la 'A' y los saltos, vuelve a esperar 1 seg
                    else begin
                        char_idx <= char_idx + 1;
                        state <= 1;
                    end
                end
            end
        endcase
    end

    // Instancia del transmisor serial
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst (
        .clk(clk),
        .send(send),
        .data(data),
        .tx(uart_tx_pin),
        .busy(busy)
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