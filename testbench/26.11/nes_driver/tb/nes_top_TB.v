// ============================================================================
// nes_top_TB.v  -  Testbench del top (nes_top) con boton S1 como reset
//
// Usa PERIOD_US = 200 para no esperar 16.6 ms entre lecturas.
// Verifica que buttons[7:0] refleje los 8 botones del control NES y que S1
// ponga la salida en 0.
// ============================================================================
`timescale 1ns/1ps

module nes_top_TB;

    reg clk = 1'b0;
    always #18.518 clk = ~clk;

    reg  s1 = 1'b0;                           // S1 presionado = reset
    wire nes_latch, nes_clock, nes_data;
    wire [7:0] buttons;

    nes_top #(.PERIOD_US(200)) dut (
        .clk       (clk),
        .s1        (s1),
        .nes_latch (nes_latch),
        .nes_clock (nes_clock),
        .nes_data  (nes_data),
        .buttons   (buttons)
    );

    // Modelo del control NES (4021)
    reg [7:0] pressed = 8'h00;
    reg [7:0] sr      = 8'hFF;
    always @(posedge nes_latch or posedge nes_clock) begin
        if (nes_latch) sr <= ~pressed;
        else           sr <= {1'b1, sr[7:1]};
    end
    assign nes_data = sr[0];

    integer errors = 0;

    task check(input [7:0] expected, input [127:0] name);
        begin
            if (buttons !== expected) begin
                $display("[ERROR] %0s: buttons = %b, esperado %b", name, buttons, expected);
                errors = errors + 1;
            end else
                $display("[ OK  ] %0s: buttons = %b", name, buttons);
        end
    endtask

    initial begin
        #5_000_000;
        $display("[ERROR] TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("nes_top_TB.vcd");
        $dumpvars(0, nes_top_TB);

        // Reset con S1
        repeat (10) @(posedge clk);
        s1 = 1'b1;                            // suelta S1

        pressed = 8'b1100_0101;               // A, Select, Left, Right
        #600_000;
        check(8'b1100_0101, "patron 1");

        pressed = 8'b0011_1010;               // B, Start, Up, Down
        #600_000;
        check(8'b0011_1010, "patron 2");

        pressed = 8'b0000_0000;
        #600_000;
        check(8'b0000_0000, "ninguno");

        pressed = 8'b1111_1111;
        #600_000;
        check(8'b1111_1111, "todos   ");

        // Reset con S1 -> buttons = 0
        s1 = 1'b0;
        #1_000;
        check(8'b0000_0000, "reset S1");
        s1 = 1'b1;

        if (errors == 0) $display("\n*** PRUEBA TOP EXITOSA ***");
        else             $display("\n*** PRUEBA TOP FALLIDA: %0d errores ***", errors);
        $finish;
    end

endmodule
