module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6   // Depth = 2^6 = 64
)(
    input  wire wr_clk, wr_rst,
    input  wire rd_clk, rd_rst,
    input  wire wr_en,
    input  wire rd_en,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire full,
    output wire empty
);

localparam DEPTH = (1 << ADDR_WIDTH);

// -----------------------------
// MEMORY
// -----------------------------
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// -----------------------------
// POINTERS (Binary + Gray)
// -----------------------------
reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
reg [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;

// Next pointers
wire [ADDR_WIDTH:0] wr_ptr_bin_next;
wire [ADDR_WIDTH:0] wr_ptr_gray_next;
wire [ADDR_WIDTH:0] rd_ptr_bin_next;
wire [ADDR_WIDTH:0] rd_ptr_gray_next;

// -----------------------------
// POINTER NEXT LOGIC
// -----------------------------
assign wr_ptr_bin_next  = wr_ptr_bin + (wr_en && !full);
assign wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

assign rd_ptr_bin_next  = rd_ptr_bin + (rd_en && !empty);
assign rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;


// -----------------------------
// WRITE DOMAIN (wr_clk)
// -----------------------------
always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
        wr_ptr_bin  <= 0;
        wr_ptr_gray <= 0;
    end else begin
        if (wr_en && !full)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= din;

        wr_ptr_bin  <= wr_ptr_bin_next;
        wr_ptr_gray <= wr_ptr_gray_next;
    end
end


// -----------------------------
// READ DOMAIN (rd_clk)
// -----------------------------
always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
        rd_ptr_bin  <= 0;
        rd_ptr_gray <= 0;
        dout        <= 0;
    end else begin
        if (rd_en && !empty)
            dout <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

        rd_ptr_bin  <= rd_ptr_bin_next;
        rd_ptr_gray <= rd_ptr_gray_next;
    end
end


// -----------------------------
// POINTER SYNCHRONIZATION
// -----------------------------

// Write pointer → Read clock domain
reg [ADDR_WIDTH:0] wr_ptr_gray_rd1, wr_ptr_gray_rd2;

always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
        wr_ptr_gray_rd1 <= 0;
        wr_ptr_gray_rd2 <= 0;
    end else begin
        wr_ptr_gray_rd1 <= wr_ptr_gray;
        wr_ptr_gray_rd2 <= wr_ptr_gray_rd1;
    end
end


// Read pointer → Write clock domain
reg [ADDR_WIDTH:0] rd_ptr_gray_wr1, rd_ptr_gray_wr2;

always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
        rd_ptr_gray_wr1 <= 0;
        rd_ptr_gray_wr2 <= 0;
    end else begin
        rd_ptr_gray_wr1 <= rd_ptr_gray;
        rd_ptr_gray_wr2 <= rd_ptr_gray_wr1;
    end
end


// -----------------------------
// FULL CONDITION (WRITE DOMAIN)
// -----------------------------
assign full =
    (wr_ptr_gray_next ==
     {~rd_ptr_gray_wr2[ADDR_WIDTH:ADDR_WIDTH-1],
       rd_ptr_gray_wr2[ADDR_WIDTH-2:0]});


// -----------------------------
// EMPTY CONDITION (READ DOMAIN)
// -----------------------------
assign empty = (rd_ptr_gray == wr_ptr_gray_rd2);

endmodule