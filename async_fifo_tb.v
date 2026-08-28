`timescale 1ns/1ps

module async_fifo_tb;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 6;
    parameter DEPTH      = (1 << ADDR_WIDTH);
    reg wr_clk;
    reg rd_clk;
    // Write clock = 100 MHz
    initial begin
        wr_clk = 1'b0;
        forever #5 wr_clk = ~wr_clk;
    end
    // Read clock ~= 71.43 MHz
    initial begin
        rd_clk = 1'b0;
        forever #7 rd_clk = ~rd_clk;
    end
    reg wr_rst_n;
    reg rd_rst_n;
    reg                     wr_en;
    reg                     rd_en;
    reg [DATA_WIDTH-1:0]    data_in;
    wire [DATA_WIDTH-1:0]   data_out;
    wire                    buff_full;
    wire                    buff_empty;

    reg [DATA_WIDTH-1:0] expected_data [0:4095];

    integer write_count;
    integer read_count;
    integer errors;

    integer i;

    reg [DATA_WIDTH-1:0] expected_value;
    reg [DATA_WIDTH-1:0] random_value;

    async_fifo () dut (

        .wr_clk(wr_clk),
        .rd_clk(rd_clk),

        .wr_rst_n(wr_rst_n),
        .rd_rst_n(rd_rst_n),

        .wr_en(wr_en),
        .rd_en(rd_en),

        .data_in(data_in),
        .data_out(data_out),

        .buff_full(buff_full),
        .buff_empty(buff_empty)

    );

    // RESET TASK
    task reset_fifo;
    begin

        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;

        wr_en    = 1'b0;
        rd_en    = 1'b0;

        data_in  = {DATA_WIDTH{1'b0}};

        // Hold reset for both clock domains
        repeat (5)
            @(posedge wr_clk);

        repeat (5)
            @(posedge rd_clk);

        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        // Allow synchronizers to settle
        repeat (4)
            @(posedge wr_clk);

        repeat (4)
            @(posedge rd_clk);

    end
    endtask

    // WRITE TASK

    task write_fifo;
        input [DATA_WIDTH-1:0] value;
    begin

        // Change controls away from active clock edge
        @(negedge wr_clk);

        // Wait while FIFO is full
        while (buff_full === 1'b1) begin
            @(negedge wr_clk);
        end

        data_in = value;
        wr_en   = 1'b1;

        @(posedge wr_clk);

        #1;

        wr_en = 1'b0;

        // Add to scoreboard only after write clock edge
        expected_data[write_count] = value;

        $display(
            "[%0t ns] WRITE  #%0d  DATA=%02h",
            $time,
            write_count,
            value
        );

        write_count = write_count + 1;

    end
    endtask

    // READ TASK

    task read_fifo;
    begin

        @(negedge rd_clk);

        // Wait while FIFO is empty
        while (buff_empty === 1'b1) begin
            @(negedge rd_clk);
        end

        expected_value = expected_data[read_count];

        rd_en = 1'b1;

        @(posedge rd_clk);

        #1;

        rd_en = 1'b0;

        // fifo_mem performs a registered read
        #1;

        if (data_out !== expected_value) begin

            $display("");
            $display(
                "[%0t ns] READ ERROR #%0d",
                $time,
                read_count
            );

            $display(
                "             EXPECTED = %02h",
                expected_value
            );

            $display(
                "             ACTUAL   = %02h",
                data_out
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "[%0t ns] READ   #%0d  DATA=%02h  PASS",
                $time,
                read_count,
                data_out
            );

        end

        read_count = read_count + 1;

    end
    endtask

    // CHECK EMPTY

    task check_empty;
    begin

        // Allow pointer synchronization to propagate
        repeat (4)
            @(posedge rd_clk);

        if (buff_empty !== 1'b1) begin

            $display(
                "[%0t ns] ERROR: FIFO should be EMPTY",
                $time
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "[%0t ns] EMPTY CHECK PASS",
                $time
            );

        end

    end
    endtask

    // CHECK FULL

    task check_full;
    begin

        // Allow read pointer synchronization
        repeat (4)
            @(posedge wr_clk);

        if (buff_full !== 1'b1) begin

            $display(
                "[%0t ns] ERROR: FIFO should be FULL",
                $time
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "[%0t ns] FULL CHECK PASS",
                $time
            );

        end

    end
    endtask

    // WAIT UNTIL EMPTY

    task wait_until_empty;
    begin

        while (buff_empty !== 1'b1) begin
            @(posedge rd_clk);
        end
    end
    endtask

    // TEST 1 : RESET

    task test_reset;
    begin

        $display("");
        $display("TEST 1 : RESET");

        if (buff_empty !== 1'b1) begin

            $display(
                "FAIL: FIFO should be EMPTY after reset"
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASS: FIFO EMPTY after reset"
            );

        end

        if (buff_full !== 1'b0) begin

            $display(
                "FAIL: FIFO should NOT be FULL after reset"
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASS: FIFO NOT FULL after reset"
            );

        end

    end
    endtask

    // TEST 2 : BASIC WRITE / READ

    task test_basic;
    begin

        $display("");
        $display("TEST 2 : BASIC WRITE / READ");

        write_fifo(8'h11);
        write_fifo(8'h22);
        write_fifo(8'h33);
        write_fifo(8'h44);
        write_fifo(8'h55);

        repeat (5)
            @(posedge rd_clk);

        read_fifo();
        read_fifo();
        read_fifo();
        read_fifo();
        read_fifo();

        check_empty();

    end
    endtask

    // TEST 3 : FIFO ORDERING

    task test_order;
    begin

        $display("");
        $display("TEST 3 : FIFO ORDER");

        for (i = 0; i < 20; i = i + 1) begin

            write_fifo(8'hA0 + i);

        end

        repeat (5)
            @(posedge rd_clk);

        for (i = 0; i < 20; i = i + 1) begin

            read_fifo();

        end

        check_empty();

    end
    endtask

    // TEST 4 : FILL FIFO TO FULL

    task test_full;
    begin

        $display("");
        $display("TEST 4 : FILL FIFO TO FULL");

        for (i = 0; i < DEPTH; i = i + 1) begin

            write_fifo(i[DATA_WIDTH-1:0]);

        end

        check_full();

        $display(
            "Expected FIFO depth = %0d",
            DEPTH
        );

        $display(
            "Writes accepted       = %0d",
            DEPTH
        );

    end
    endtask

    // TEST 5 : DRAIN FIFO TO EMPTY

    task test_empty;
    begin

        $display("");
        $display("TEST 5 : DRAIN FIFO TO EMPTY");

        for (i = 0; i < DEPTH; i = i + 1) begin

            read_fifo();

        end

        check_empty();

    end
    endtask

    // TEST 6 : ALTERNATING WRITE / READ

    task test_alternating;
    begin

        $display("");
        $display("TEST 6 : ALTERNATING WRITE / READ");

        for (i = 0; i < 30; i = i + 1) begin

            write_fifo(8'h40 + i);

            // Read every second write
            if ((i % 2) == 1) begin

                repeat (2)
                    @(posedge rd_clk);

                read_fifo();

            end

        end

        // Drain remaining entries
        while (read_count < write_count) begin

            read_fifo();

        end

        check_empty();

    end
    endtask

    // TEST 7 : CONCURRENT WRITE / READ
    // Separate write-clock and read-clock domains operate independently.

    task test_concurrent;
    begin

        $display("");
        $display("TEST 7 : CONCURRENT WRITE / READ");

        fork

            begin : WRITE_PROCESS

                integer j;

                for (j = 0; j < 100; j = j + 1) begin

                    write_fifo(
                        8'h80 + (j & 8'h3F)
                    );

                end

            end

            begin : READ_PROCESS

                integer k;

                // Give write side time to put initial data in FIFO
                repeat (8)
                    @(posedge rd_clk);

                for (k = 0; k < 100; k = k + 1) begin

                    read_fifo();

                end

            end

        join

        check_empty();

    end
    endtask

    // TEST 8 : RANDOM TRAFFIC
    // Writer and reader run concurrently using the two different clocks.

    task test_random;
    begin

        $display("");
        $display("TEST 8 : RANDOM CONCURRENT TRAFFIC");

        fork

            begin : RANDOM_WRITER

                integer j;

                for (j = 0; j < 150; j = j + 1) begin

                    random_value = $random;

                    write_fifo(random_value);

                end

            end

            begin : RANDOM_READER

                integer k;

                // Wait for initial data
                repeat (10)
                    @(posedge rd_clk);

                for (k = 0; k < 150; k = k + 1) begin

                    read_fifo();

                end

            end

        join

        check_empty();

    end
    endtask

    // MAIN TEST SEQUENCE

    initial begin

        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;

        wr_en = 1'b0;
        rd_en = 1'b0;

        data_in = 8'h00;

        write_count = 0;
        read_count  = 0;
        errors      = 0;


        reset_fifo();

        $display("");
        $display("#        ASYNCHRONOUS FIFO TESTBENCH          #");

        $display("");
        $display("DATA WIDTH = %0d", DATA_WIDTH);
        $display("ADDR WIDTH = %0d", ADDR_WIDTH);
        $display("FIFO DEPTH = %0d", DEPTH);

        // TESTS

        test_reset();

        test_basic();

        test_order();

        test_full();

        test_empty();

        test_alternating();

        test_concurrent();

        test_random();

        // FINAL WAIT

        repeat (10)
            @(posedge wr_clk);

        repeat (10)
            @(posedge rd_clk);

        // FINAL REPORT

        $display("");
        $display("                 FINAL REPORT");

        $display(
            "Total writes = %0d",
            write_count
        );

        $display(
            "Total reads  = %0d",
            read_count
        );

        $display(
            "Total errors = %0d",
            errors
        );

        if (write_count != read_count) begin

            $display(
                "WARNING: write/read count mismatch"
            );

            errors = errors + 1;

        end

        // PASS / FAIL

        if (errors == 0) begin

            $display("");
            $display("*        ASYNCHRONOUS FIFO TEST PASSED        *");


        end
        else begin

            $display("");
            $display("*        ASYNCHRONOUS FIFO TEST FAILED        *");

        end

        $display("");

        $finish;

    end

    // WAVEFORM DUMP

    initial begin

        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, async_fifo_tb);

    end

    // TIMEOUT

    initial begin

        #100000;

        $display("");
        $display("*             SIMULATION TIMEOUT              *");
        $display("");

        $finish;

    end

endmodule
