module two_ff_sync (
    input  wire clk,
    input  wire rst_n,
    input reg [6:0] din;
    output reg [6:0]  q2;
);

    reg [6:0] q1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q2<=7'b0;
            q1<=7'b0;
        end else begin
            q2 <= q1;
            q1 <= din;
        end
    end

endmodule
