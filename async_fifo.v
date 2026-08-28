module async_fifo (
    input wire wr_clk,
    input wire rd_clk,
    input wire wr_rst_n,
    input wire rd_rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [7:0] data_in,
    output wire [7:0] data_out,
    output wire buff_full,
    output wire buff_empty
);
// pointer width: 64 depth fifo
// address : 6 bits, pointer: 7 bits (1 extra for grey)

// binary, grey ptr
wire [6:0] g_wrptr;
wire [6:0] b_wrptr;

wire [6:0] g_rdptr;
wire [6:0] b_rdptr;

wire [6:0] g_rdptr_sync;
wire [6:0] g_wrptr_sync;

// instantitate logics
fifo_empty ufe(
    .rd_clk(rd_clk),
    .rd_rst_n(rd_rst_n),
    .rd_en(rd_en),
    .g_wrptr_sync(g_wrptr_sync),
    .buff_empty(buff_empty),
    .b_rdptr(b_rdptr),
    .g_rdptr(g_rdptr)
    
);

fifo_full uff(
    .wr_clk(wr_clk),
    .wr_rst_n(wr_rst_n),
    .wr_en(wr_en),
    .g_rdptr_sync(g_rdptr_sync),
    .buff_full(buff_full),
    .b_wrptr(b_wrptr),
    .g_wrptr(g_wrptr)
);
// read ptr to write clk domain
two_ff_sync u_sync_rd_wr(
    .clk(wr_clk),
    .rst_n(wr_rst_n),
    .din(g_rdptr),
    .q2(g_rdptr_sync)
);
//write ptr to read clk domain
two_ff_sync u_sync_wr_rd(
    .clk(rd_clk),
    .rst_n(rd_rst_n),
    .din(g_wrptr),
    .q2(g_wrptr_sync)
);

fifo_mem ufm(
    
    .wr_clk(wr_clk),
    .rd_clk(rd_clk),
    
    .wr_en(wr_en),
    .rd_en(rd_en),
    
    .buff_full(buff_full),
    .buff_empty(buff_empty),

    .data_in(data_in),

    .b_wrptr(b_wrptr),
    .b_rdptr(b_rdptr),
    
    .data_out(data_out)

);

endmodule
