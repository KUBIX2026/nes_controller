`timescale 1ns / 1ps

module tb_nes_controller;

    // Entradas al módulo (Salidas del Testbench)
    reg clk;
    reg rst_n;
    wire nes_data;

    // Salidas del módulo (Entradas al Testbench)
    wire nes_latch;
    wire nes_clk;
    wire [7:0] buttons;

    // Variables internas del Testbench para emular el control
    reg [7:0] mock_buttons; // Estado virtual de los botones (0 = Presionado)
    reg [7:0] shift_reg;    // Registro de desplazamiento interno del "control"

    // Instanciación del módulo a probar (UUT - Unit Under Test)
    nes_controller #(
        .CLK_FREQ(25000000),
        // IMPORTANTE: Aceleramos el refresh rate a 5000 Hz (en vez de 60 Hz) 
        // solo en la simulación para no tener que esperar milisegundos de 
        // tiempo simulado entre lecturas, lo cual haría el archivo VCD gigante.
        .REFRESH_RATE(5000) 
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .nes_data(nes_data),
        .nes_latch(nes_latch),
        .nes_clk(nes_clk),
        .buttons(buttons)
    );

    // 1. Generación de Reloj a 25 MHz (Periodo de 40 ns -> 20 ns alto, 20 ns bajo)
    always #20 clk = ~clk;

    // 2. Emulación del Control de NES (Chip CD4021)
    // El Latch carga los datos asíncronamente. El Clock desplaza los bits.
    always @(posedge nes_latch or posedge nes_clk) begin
        if (nes_latch) begin
            shift_reg <= mock_buttons; // Cargar el estado actual de los botones
        end else if (nes_clk) begin
            shift_reg <= {1'b1, shift_reg[7:1]}; // Desplazar a la derecha, rellenar con 1 (no presionado)
        end
    end

    // El pin de datos del NES siempre muestra el bit menos significativo del registro
    assign nes_data = shift_reg[0];

    // 3. Estímulos (Secuencia de prueba)
    initial begin
        // Configurar GTKWave para guardar las señales
        $dumpfile("tb_nes_controller.vcd");
        $dumpvars(0, tb_nes_controller);

        // Estado inicial
        clk = 0;
        rst_n = 0;
        // Orden: [Derecha, Izquierda, Abajo, Arriba, Start, Select, B, A]
        // 1 = Suelto, 0 = Presionado
        mock_buttons = 8'b11111111; // Ningún botón presionado

        // Quitar reset después de 100 ns
        #100 rst_n = 1;

        // Esperar al primer ciclo de lectura (a 5kHz toma ~200us)
        #250000; 

        // PRUEBA 1: Presionar 'A' (Bit 0) y 'Start' (Bit 3)
        // Binario: 1111_0110
        $display("Simulando pulsación: A y Start");
        mock_buttons = 8'b11110110;
        #250000; // Esperar al siguiente ciclo de lectura
        
        // PRUEBA 2: Soltar todo, presionar 'Derecha' (Bit 7) y 'B' (Bit 1)
        // Binario: 0111_1101
        $display("Simulando pulsación: Derecha y B");
        mock_buttons = 8'b01111101;
        #250000; // Esperar lectura
        
        // PRUEBA 3: Presionar todos los botones (A veces pasa por error de hardware)
        // Binario: 0000_0000
        $display("Simulando pulsación: Todos los botones");
        mock_buttons = 8'b00000000;
        #250000; 

        $display("Simulación terminada.");
        $finish;
    end

endmodule