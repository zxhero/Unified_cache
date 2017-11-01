module single_port_blockram
#(
    parameter SINGLE_ELEMENT_SIZE_IN_BITS = 10,
    parameter NUMBER_SETS                 = 64,
    parameter SET_PTR_WIDTH_IN_BITS       = 6
)
(
    input                                            reset_in,
    input                                            clk_in,

    input                                            access_en_in,
    input                                            write_en_in,
    input      [SET_PTR_WIDTH_IN_BITS       - 1 : 0] access_set_addr_in,

    input      [SINGLE_ELEMENT_SIZE_IN_BITS - 1 : 0] write_element_in,
    output reg [SINGLE_ELEMENT_SIZE_IN_BITS - 1 : 0] read_element_out
);

(* ram_style = "block" *) reg [SINGLE_ELEMENT_SIZE_IN_BITS - 1 : 0] blockram [NUMBER_SETS - 1 : 0];

always @(posedge clk_in)
begin
    if(access_en_in)
    begin
        
        read_element_out <= blockram[access_set_addr_in];

        if(write_en_in)
        begin
            blockram[access_set_addr_in] <= write_element_in;
        end
    end
end
endmodule
