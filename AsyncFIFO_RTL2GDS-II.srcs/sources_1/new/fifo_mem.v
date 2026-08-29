module fifo_mem (
    input  wire        wr_clk,
    input  wire        rd_clk,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire        buff_full,
    input  wire        buff_empty,
    input  wire [7:0]  data_in,
    input  wire [6:0]  b_wrptr,
    input  wire [6:0]  b_rdptr,
    output reg  [7:0]  data_out
);
    // depth of fifo = 64 and each with 8bit register
    reg [7:0] mem [0:63];
    
    // Write (wr_clk domain)
    always @(posedge wr_clk) begin
        if (wr_en && !buff_full) begin
            mem[b_wrptr[5:0]] <= data_in;
        end
    end

    // Read (rd_clk domain)
    always @(posedge rd_clk) begin
        if (rd_en && !buff_empty) begin
            data_out <= mem[b_rdptr[5:0]];
        end
    end

endmodule