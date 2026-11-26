// ============================================================================
// nes_bit_counter.v  -  Bloque "Contador de bits" del diagrama de bloques
//
//   Entradas : clk_in, rst_n, cnt_en
//   Salidas  : bits_done
//
// Cuenta las lecturas (pulsos de cnt_en). bits_done se pone en 1 al contar
// el 8vo bit y se mantiene hasta la primera lectura de la siguiente trama,
// por lo que la FSM puede consultarlo con calma en CLK_HIGH.
// El contador de 3 bits da la vuelta solo (7 -> 0): no necesita otra senal
// de reinicio, tal como en el diagrama de bloques.
// ============================================================================
module nes_bit_counter (
    input  wire clk_in,
    input  wire rst_n,
    input  wire cnt_en,
    output reg  bits_done
);

    reg [2:0] count;

    always @(posedge clk_in) begin
        if (!rst_n) begin
            count     <= 3'd0;
            bits_done <= 1'b0;
        end else if (cnt_en) begin
            count     <= count + 3'd1;
            bits_done <= (count == 3'd7);   // 8va lectura -> terminado
        end
    end

endmodule
