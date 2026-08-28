module fifo_full (
    input wire wr_clk, wr_rst_n, wr_en, 
    input reg[6:0] g_rdptr_sync,
    output reg buff_full;
    output reg [6:0] b_wrptr;
    output reg [6:0] g_wrptr;

);

reg [6:0] b_wrptr_next;
reg [6:0] g_wrptr_next;
//fsm
always @(posedge wr_clk or negedge wr_rst_n) begin
    if(!wr_rst_n)begin
        b_wrptr <= 7'b0;
        g_wrptr <= 7'b0;
    end
    else begin
        b_wrptr <= b_wrptr_next;
        g_wrptr <= g_wrptr_next;
    end
end


always @(*) begin
    if(wr_en && !buff_full)begin
        b_wrptr_next = b_wrptr + 1'b1;
    end 
end
    
// b2g

assign g_wrptr_next = (b_wrptr_next>>1) ^ b_wrptr_next;

// full logic
assign buff_full_val = (g_wrptr_next=={~g_rdptr_sync[6:5],g_rdptr_sync[4:0]});
in
always @(posedge wr_clk or negedge wr_rst_n) begin
    if(!wr_rst_n)begin
        buff_full <= 1'b0;
    end
    else begin
        buff_full <= buff_full_val;
    end
end


endmodule
