module fifo_empty (
    input wire rd_clk, rd_rst_n, rd_en, 
    input reg[6:0] g_wrptr_sync,
    output reg buff_empty;
    output reg [6:0] b_rdptr;
    output reg [6:0] g_rdptr;

);

reg [6:0] b_rdptr_next;
reg [6:0] g_rdptr_next;
//fsm
always @(posedge rd_clk or negedge rd_rst_n) begin
    if(!rd_rst_n)begin
        b_rdptr <= 7'b0;
        g_rdptr <= 7'b0;
    end
    else begin
        b_rdptr <= b_rdptr_next;
        g_rdptr <= g_rdptr_next;
    end
end


always @(*) begin
    if(rd_en && !buff_empty)begin
        b_rdptr_next = b_rdptr + 1'b1;
    end 
end
    
// b2g

assign g_rdptr_next = (b_rdptr_next>>1) ^ b_rdptr_next;

// full logic
assign buff_empty_val = (g_rdptr_next==g_rdptr_sync);

always @(posedge rd_clk or negedge rd_rst_n) begin
    if(!rd_rst_n)begin
        buff_empty <= 0;
    end
    else begin
        buff_empty <= buff_empty_val;
    end
end


endmodule
