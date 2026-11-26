// ============================================================================
// nes_driver_TB.v  -  Testbench del modulo nes_driver
//
// Incluye un modelo del control NES (registro 4021: carga paralela con LATCH,
// desplazamiento con el flanco de subida de CLOCK, logica negativa) y revisa:
//   * El byte leido coincide con los botones presionados (varios patrones)
//   * LATCH dura 12 us, CLOCK en alto dura 6 us, CLOCK en bajo ~6 us
//   * 8 pulsos de CLOCK por lectura
//   * ready = 1 al final de cada lectura
//   * Un reset en medio de una lectura aborta la trama y la siguiente sale bien
//
// Uso:  make sim        (iverilog + gtkwave)       make test  (sin gtkwave)
// ============================================================================
`timescale 1ns/1ps

module nes_driver_TB;

    // ---- Reloj de 27 MHz ----------------------------------------------------
    reg clk_in = 1'b0;
    always #18.518 clk_in = ~clk_in;          // periodo ~37.037 ns

    // ---- Senales ------------------------------------------------------------
    reg        rst_n      = 1'b0;
    reg        start_read = 1'b0;
    wire       data;
    wire       latch, clock, ready;
    wire [7:0] buttons;

    nes_driver dut (
        .clk_in     (clk_in),
        .rst_n      (rst_n),
        .start_read (start_read),
        .data       (data),
        .latch      (latch),
        .clock      (clock),
        .ready      (ready),
        .buttons    (buttons)
    );

    // ---- Modelo del control NES (4021) ----------------------------------------
    reg [7:0] pressed = 8'h00;                // 1 = boton presionado
    reg [7:0] sr      = 8'hFF;

    always @(posedge latch or posedge clock) begin
        if (latch) sr <= ~pressed;            // carga paralela (logica negativa)
        else       sr <= {1'b1, sr[7:1]};     // desplaza con CLOCK
    end

    assign data = sr[0];

    // ---- Monitores de temporizacion -------------------------------------------
    integer errors      = 0;
    integer clk_pulses  = 0;
    reg     check_timing = 1'b1;
    real    t_latch_up, t_clk_up, t_clk_down;
    real    w;

    always @(posedge latch) begin
        t_latch_up = $realtime;
        clk_pulses = 0;
    end

    always @(negedge latch) if (check_timing) begin
        w = $realtime - t_latch_up;
        if (w < 11950.0 || w > 12050.0) begin
            $display("[ERROR] ancho de LATCH = %0.1f ns (esperado 12000)", w);
            errors = errors + 1;
        end
    end

    always @(posedge clock) begin
        if (check_timing && clk_pulses > 0) begin
            w = $realtime - t_clk_down;       // CLOCK en bajo entre pulsos
            if (w < 5950.0 || w > 6100.0) begin
                $display("[ERROR] CLOCK en bajo = %0.1f ns (esperado ~6000)", w);
                errors = errors + 1;
            end
        end
        t_clk_up   = $realtime;
        clk_pulses = clk_pulses + 1;
    end

    always @(negedge clock) begin
        t_clk_down = $realtime;
        if (check_timing) begin
            w = $realtime - t_clk_up;         // CLOCK en alto
            if (w < 5950.0 || w > 6050.0) begin
                $display("[ERROR] CLOCK en alto = %0.1f ns (esperado 6000)", w);
                errors = errors + 1;
            end
        end
    end

    // ---- Tareas -----------------------------------------------------------------
    task pulse_start;
        begin
            @(negedge clk_in) start_read = 1'b1;
            @(negedge clk_in) start_read = 1'b0;
        end
    endtask

    task do_read(input [7:0] pat);
        begin
            pressed = pat;
            pulse_start;
            @(posedge ready);
            #1;
            if (buttons !== pat) begin
                $display("[ERROR] botones = %b, esperado %b", buttons, pat);
                errors = errors + 1;
            end else begin
                $display("[ OK  ] botones = %b  (t = %0t ns)", buttons, $time/1000);
            end
            if (clk_pulses !== 8) begin
                $display("[ERROR] pulsos de CLOCK = %0d (esperado 8)", clk_pulses);
                errors = errors + 1;
            end
            repeat (20) @(posedge clk_in);    // vuelve a START
        end
    endtask

    // ---- Traza (solo con -DBENCH, que usa "make sim") ------------------------
`ifdef BENCH
    always @(latch or clock or ready)
        $display("%0t ns  latch=%b clock=%b ready=%b data=%b",
                 $time/1000, latch, clock, ready, data);
`endif

    // ---- Watchdog ----------------------------------------------------------------
    initial begin
        #5_000_000;
        $display("[ERROR] TIMEOUT");
        $finish;
    end

    // ---- Estimulo ------------------------------------------------------------------
    initial begin
        $dumpfile("nes_driver_TB.vcd");
        $dumpvars(0, nes_driver_TB);

        // Reset inicial
        rst_n = 1'b0;
        repeat (5) @(posedge clk_in);
        @(negedge clk_in) rst_n = 1'b1;
        repeat (10) @(posedge clk_in);

        // Lecturas con distintos patrones
        do_read(8'b0000_0000);                // nada presionado
        do_read(8'b1010_0101);
        do_read(8'b0000_0001);                // solo A
        do_read(8'b1000_0000);                // solo Right
        do_read(8'b1111_1111);                // todo presionado

        // Reset en medio de una lectura
        $display("--- Reset a mitad de lectura ---");
        pressed = 8'b0101_1010;
        check_timing = 1'b0;
        pulse_start;
        #50_000;                              // ~50 us dentro de la trama
        @(negedge clk_in) rst_n = 1'b0;
        repeat (4) @(posedge clk_in);
        #1;
        if (latch !== 1'b0 || clock !== 1'b0 || ready !== 1'b0) begin
            $display("[ERROR] salidas no quedaron en 0 durante el reset");
            errors = errors + 1;
        end
        @(negedge clk_in) rst_n = 1'b1;
        repeat (10) @(posedge clk_in);
        check_timing = 1'b1;
        do_read(8'b0110_0110);                // la lectura posterior debe salir bien

        if (errors == 0) $display("\n*** PRUEBA EXITOSA: sin errores ***");
        else             $display("\n*** PRUEBA FALLIDA: %0d errores ***", errors);
        $finish;
    end

endmodule
