
module Cache (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,        // data input bus
    output wire [ 7:0] mem_dout,       // data output bus
    output wire [31:0] mem_a,          // address bus (only 17:0 is used)
    output wire        mem_wr,         // write/read signal (1 for write)
    input  wire        io_buffer_full,

    input wire rob_clear,

    input wire inst_valid,
    input wire [31:0] PC,
    output wire inst_ready,
    output wire [31:0] inst_res,

    input  wire        data_valid,
    input  wire        data_wr,
    // data_size[1:0] 0: byte, 1: halfword, 2: word
    // data_size[2] signed or not signed
    input  wire [ 2:0] data_size,
    input  wire [31:0] data_addr,
    input  wire [31:0] data_value,
    output wire        data_ready,
    output wire [31:0] data_res
);
    // mx: MemoryCtrl
    reg         mc_enable;
    reg         mc_wr;
    reg  [31:0] mc_addr;
    reg  [ 2:0] mc_len;
    reg  [31:0] mc_data;
    wire        mc_ready;
    wire [31:0] mc_res;
    wire        i_hit;
    wire [31:0] i_res;
    wire        i_we;  // i cache write enable
    InstuctionCache iCache (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .addr(PC),
        .hit (i_hit),
        .res (i_res),
        .we  (i_we),
        .data(mc_res)
    );

    MemoryController memCtrl (
        .clk_in(clk_in),
        .rst_in(rst_in | rob_clear),
        .rdy_in(rdy_in),

        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),
        .io_buffer_full(io_buffer_full),

        .valid(mc_enable),
        .wr(mc_wr),
        .addr(mc_addr),
        .len(mc_len),
        .data(mc_data),
        .ready(mc_ready),
        .res(mc_res)
    );


    reg working;
    reg work_type;

    assign data_ready = working && work_type && mc_ready;
    assign data_res = mc_res;
    assign inst_ready = i_hit;
    assign inst_res = i_res;
    assign i_we = working && !work_type && mc_ready;

    always @(posedge clk_in) begin
        if (rst_in | rob_clear) begin
            working <= 0;
            work_type <= 0;
            mc_enable <= 0;
            mc_wr <= 0;
            mc_addr <= 0;
            mc_len <= 0;
            mc_data <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (!working) begin
            if (data_valid) begin
                working <= 1;
                work_type <= 1;
                mc_enable <= 1;
                mc_wr <= data_wr;
                mc_addr <= data_addr;
                mc_len <= data_size;
                mc_data <= data_value;
            end
            else if (inst_valid && !inst_ready) begin
                working <= 1;
                work_type <= 0;
                mc_enable <= 1;
                mc_wr <= 0;
                mc_addr <= PC;
                mc_len <= 3'b010;
                mc_data <= 0;
            end
        end
        else if (mc_ready) begin
            working   <= 0;
            mc_enable <= 0;
        end
    end

endmodule
