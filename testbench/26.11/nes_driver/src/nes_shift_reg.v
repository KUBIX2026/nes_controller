// ============================================================================
// nes_shift_reg.v  -  Bloque "Registro de corrimiento" del diagrama de bloques
//
//   Entradas : clk_in, rst_n, shift_en, data
//   Salidas  : buttons[7:0]
//
// Con cada pulso de shift_en entra el bit 'data' por el MSB y el registro se
// desplaza a la derecha. Tras 8 desplazamientos el primer bit recibido queda
// en buttons[0], como en el diagrama de flujo (botones[0] = data, ...).
//
// Orden NES:  [0]=A [1]=B [2]=Select [3]=Start [4]=Up [5]=Down [6]=Left [7]=Right
//
// El control NES entrega los botones en logica negativa (presionado = 0).
// El "Aplicar NOT" del diagrama de flujo se hace en la asignacion de salida:
// buttons[i] = 1 significa boton presionado.
// ============================================================================
module nes_shift_reg (
    input  wire       clk_in,
    input  wire       rst_n,
    input  wire       shift_en,
    input  wire       data,
    output wire [7:0] buttons
);

    reg [7:0] sreg;

    always @(posedge clk_in) begin
        if (!rst_n)
            sreg <= 8'hFF;                        // nada presionado
        else if (shift_en)
            sreg <= {data, sreg[7:1]};
    end

    assign buttons = ~sreg;                       // Aplicar NOT

endmodule
