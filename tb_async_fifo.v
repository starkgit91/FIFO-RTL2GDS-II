`timescale 1ns/1ps

module tb_async_fifo;

    // ============================================================
    // PARAMETERS
    // ============================================================

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 6;
    parameter DEPTH      = (1 << ADDR_WIDTH);

    // ============================================================
    // CLOCKS
    // ============================================================

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

    // ============================================================
    // RESET
    // ============================================================

    reg wr_rst_n;
    reg rd_rst_n;

    // ============================================================
    // FIFO SIGNALS
    // ============================================================

    reg wr_en;
    reg rd_en;

    reg [DATA_WIDTH-1:0] data_in;

    wire [DATA_WIDTH-1:0] data_out;

    wire buff_full;
    wire buff_empty;

    // ============================================================
    // SCOREBOARD
    // ============================================================

    reg [DATA_WIDTH-1:0] expected_data [0:4095];

    integer write_count;
    integer read_count;
    integer errors;

    integer i;

    reg [DATA_WIDTH-1:0] expected_value;
    reg [DATA_WIDTH-1:0] random_value;

    // ============================================================
    // DUT
    // ============================================================

    async_fifo dut (
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

    // ============================================================
    // RESET TASK
    // ============================================================

    task reset_fifo;
    begin

        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;

        wr_en = 1'b0;
        rd_en = 1'b0;

        data_in = 8'h00;

        repeat (5)
            @(posedge wr_clk);

        repeat (5)
            @(posedge rd_clk);

        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        // Allow pointer synchronizers to settle
        repeat (4)
            @(posedge wr_clk);

        repeat (4)
            @(posedge rd_clk);

    end
    endtask

    // ============================================================
    // WRITE TASK
    // ============================================================

    task write_fifo;
        input [DATA_WIDTH-1:0] value;

        reg [DATA_WIDTH-1:0] accepted_value;

    begin

        accepted_value = value;

        @(negedge wr_clk);

        // Wait until FIFO is not full
        while (buff_full === 1'b1)
            @(negedge wr_clk);

        data_in = accepted_value;
        wr_en = 1'b1;

        // Actual write happens on this edge
        @(posedge wr_clk);

        #1;

        wr_en = 1'b0;

        // Add only after the write was accepted
        expected_data[write_count] = accepted_value;

        $display(
            "[%0t ns] WRITE #%0d DATA=%02h",
            $time,
            write_count,
            accepted_value
        );

        write_count = write_count + 1;

    end
    endtask

    // ============================================================
    // READ TASK
    // ============================================================

    task read_fifo;
    begin

        @(negedge rd_clk);

        // Wait until FIFO is not empty
        while (buff_empty === 1'b1)
            @(negedge rd_clk);

        expected_value = expected_data[read_count];

        rd_en = 1'b1;

        // Actual read happens here
        @(posedge rd_clk);

        #1;

        rd_en = 1'b0;

        // fifo_mem uses registered read data
        #1;

        if (data_out !== expected_value) begin

            $display("");
            $display(
                "[%0t ns] READ ERROR #%0d",
                $time,
                read_count
            );

            $display(
                "       Expected = %02h",
                expected_value
            );

            $display(
                "       Actual   = %02h",
                data_out
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "[%0t ns] READ  #%0d DATA=%02h PASS",
                $time,
                read_count,
                data_out
            );

        end

        read_count = read_count + 1;

    end
    endtask

    // ============================================================
    // CHECK EMPTY
    // ============================================================

    task check_empty;
    begin

        repeat (4)
            @(posedge rd_clk);

        if (buff_empty !== 1'b1) begin

            $display(
                "[%0t ns] ERROR: FIFO is not EMPTY",
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

    // ============================================================
    // CHECK FULL
    // ============================================================

    task check_full;
    begin

        repeat (4)
            @(posedge wr_clk);

        if (buff_full !== 1'b1) begin

            $display(
                "[%0t ns] ERROR: FIFO is not FULL",
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

    // ============================================================
    // TEST 1 : RESET
    // ============================================================

    task test_reset;
    begin

        $display("");
        $display("================================================");
        $display("TEST 1 : RESET");
        $display("================================================");

        if (buff_empty !== 1'b1) begin

            $display(
                "FAIL: buff_empty should be 1"
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
                "FAIL: buff_full should be 0"
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

    // ============================================================
    // TEST 2 : BASIC WRITE / READ
    // ============================================================

    task test_basic;
    begin

        $display("");
        $display("================================================");
        $display("TEST 2 : BASIC WRITE / READ");
        $display("================================================");

        write_fifo(8'h11);
        write_fifo(8'h22);
        write_fifo(8'h33);
        write_fifo(8'h44);
        write_fifo(8'h55);

        // Allow data to cross clock domains
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

    // ============================================================
    // TEST 3 : FIFO ORDERING
    // ============================================================

    task test_order;
    begin

        $display("");
        $display("================================================");
        $display("TEST 3 : FIFO ORDERING");
        $display("================================================");

        for (i = 0; i < 20; i = i + 1)
            write_fifo(8'hA0 + i);

        repeat (5)
            @(posedge rd_clk);

        for (i = 0; i < 20; i = i + 1)
            read_fifo();

        check_empty();

    end
    endtask

    // ============================================================
    // TEST 4 : FILL FIFO COMPLETELY
    // ============================================================

    task test_full;
    begin

        $display("");
        $display("================================================");
        $display("TEST 4 : FILL FIFO TO FULL");
        $display("================================================");

        for (i = 0; i < DEPTH; i = i + 1)
            write_fifo(i[DATA_WIDTH-1:0]);

        check_full();

        $display(
            "FIFO depth = %0d entries",
            DEPTH
        );

    end
    endtask

    // ============================================================
    // TEST 5 : DRAIN FIFO COMPLETELY
    // ============================================================

    task test_empty;
    begin

        $display("");
        $display("================================================");
        $display("TEST 5 : DRAIN FIFO TO EMPTY");
        $display("================================================");

        for (i = 0; i < DEPTH; i = i + 1)
            read_fifo();

        check_empty();

    end
    endtask

    // ============================================================
    // TEST 6 : ALTERNATING TRAFFIC
    // ============================================================

    task test_alternating;
    begin

        $display("");
        $display("================================================");
        $display("TEST 6 : ALTERNATING WRITE / READ");
        $display("================================================");

        for (i = 0; i < 30; i = i + 1) begin

            write_fifo(8'h40 + i);

            if ((i % 2) == 1) begin

                repeat (2)
                    @(posedge rd_clk);

                read_fifo();

            end

        end

        // Drain everything remaining
        while (read_count < write_count)
            read_fifo();

        check_empty();

    end
    endtask

    // ============================================================
    // TEST 7 : CONCURRENT READ / WRITE
    // ============================================================

    task test_concurrent;
    begin

        $display("");
        $display("================================================");
        $display("TEST 7 : CONCURRENT READ / WRITE");
        $display("================================================");

        fork

            begin : WRITER

                integer j;

                for (j = 0; j < 100; j = j + 1)
                    write_fifo(8'h80 + (j % 64));

            end

            begin : READER

                integer k;

                // Give writer time to fill FIFO initially
                repeat (10)
                    @(posedge rd_clk);

                for (k = 0; k < 100; k = k + 1)
                    read_fifo();

            end

        join

        check_empty();

    end
    endtask

    // ============================================================
    // TEST 8 : RANDOM CONCURRENT TRAFFIC
    // ============================================================

    task test_random;
    begin

        $display("");
        $display("================================================");
        $display("TEST 8 : RANDOM CONCURRENT TRAFFIC");
        $display("================================================");

        fork

            begin : RANDOM_WRITER

                integer j;

                for (j = 0; j < 100; j = j + 1) begin

                    random_value = $random;

                    write_fifo(random_value);

                end

            end

            begin : RANDOM_READER

                integer k;

                repeat (10)
                    @(posedge rd_clk);

                for (k = 0; k < 100; k = k + 1)
                    read_fifo();

            end

        join

        check_empty();

    end
    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;

        wr_en = 1'b0;
        rd_en = 1'b0;

        data_in = 8'h00;

        write_count = 0;
        read_count = 0;
        errors = 0;

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        reset_fifo();

        $display("");
        $display("################################################");
        $display("#                                              #");
        $display("#       ASYNCHRONOUS FIFO TESTBENCH            #");
        $display("#                VIVADO XSIM                   #");
        $display("#                                              #");
        $display("################################################");

        $display("");
        $display("DATA_WIDTH = %0d", DATA_WIDTH);
        $display("ADDR_WIDTH = %0d", ADDR_WIDTH);
        $display("DEPTH      = %0d", DEPTH);

        // --------------------------------------------------------
        // RUN TESTS
        // --------------------------------------------------------

        test_reset();

        test_basic();

        test_order();

        test_full();

        test_empty();

        test_alternating();

        test_concurrent();

        test_random();

        // --------------------------------------------------------
        // FINAL WAIT
        // --------------------------------------------------------

        repeat (10)
            @(posedge wr_clk);

        repeat (10)
            @(posedge rd_clk);

        // --------------------------------------------------------
        // FINAL REPORT
        // --------------------------------------------------------

        $display("");
        $display("================================================");
        $display("                 FINAL REPORT");
        $display("================================================");

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
                "ERROR: write/read count mismatch"
            );

            errors = errors + 1;

        end

        if (errors == 0) begin

            $display("");
            $display("************************************************");
            $display("*                                              *");
            $display("*       ASYNCHRONOUS FIFO TEST PASSED         *");
            $display("*                                              *");
            $display("************************************************");

        end
        else begin

            $display("");
            $display("************************************************");
            $display("*                                              *");
            $display("*       ASYNCHRONOUS FIFO TEST FAILED         *");
            $display("*                                              *");
            $display("************************************************");

        end

        $display("");

        $finish;

    end

    // ============================================================
    // TIMEOUT
    // ============================================================

    initial begin

        #100000;

        $display("");
        $display("************************************************");
        $display("*             SIMULATION TIMEOUT              *");
        $display("************************************************");
        $display("");

        $finish;

    end

endmodule
