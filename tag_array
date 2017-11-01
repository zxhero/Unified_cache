module unified_cache_tag_array
#(
        parameter SINGLE_TAG_SIZE_IN_BITS = 2,
        parameter NUMBER_WAYS             = 2,
        parameter NUMBER_SETS             = 2,
        parameter SET_PTR_WIDTH_IN_BITS   = 1
)
(
        input                                                      reset_in,
        input                                                      clk_in,

        input      [NUMBER_WAYS                           - 1 : 0] way_select_in,

        input                                                      read_en_in,
        input      [SET_PTR_WIDTH_IN_BITS                 - 1 : 0] read_set_addr_in,
        output     [SINGLE_TAG_SIZE_IN_BITS * NUMBER_WAYS - 1 : 0] read_tag_pack_out,

        input                                                      write_en_in,
        input      [SET_PTR_WIDTH_IN_BITS                 - 1 : 0] write_set_addr_in,        
        input      [SINGLE_TAG_SIZE_IN_BITS               - 1 : 0] write_tag_in,
        output     [SINGLE_TAG_SIZE_IN_BITS               - 1 : 0] evict_tag_out
);

wire [SINGLE_TAG_SIZE_IN_BITS * NUMBER_WAYS - 1 : 0] evict_tag_pack_to_mux;

generate
        genvar gen;

        for(gen = 0; gen < NUMBER_WAYS; gen = gen + 1)
        begin
                
                dual_port_blockram
                #(.SINGLE_ELEMENT_SIZE_IN_BITS(SINGLE_TAG_SIZE_IN_BITS), .NUMBER_SETS(NUMBER_SETS), .SET_PTR_WIDTH_IN_BITS(SET_PTR_WIDTH_IN_BITS))
                tag_way
                (
                        .clk_in            (clk_in),
                        .reset_in          (reset_in),
                        
                        .read_en_in        (read_en_in),
                        .read_set_addr_in  (read_set_addr_in),
                        .read_element_out  (read_tag_pack_out[(gen+1) * SINGLE_TAG_SIZE_IN_BITS - 1 : gen * SINGLE_TAG_SIZE_IN_BITS]),

                        .write_en_in       (write_en_in & way_select_in[gen]),
                        .write_set_addr_in (write_set_addr_in),
                        .write_element_in  (write_tag_in),
                        .evict_element_out (evict_tag_pack_to_mux[(gen+1) * SINGLE_TAG_SIZE_IN_BITS - 1 : gen * SINGLE_TAG_SIZE_IN_BITS])
                );

        end   
endgenerate

reg [NUMBER_WAYS - 1 : 0] way_select_stage;
always @(posedge clk_in or posedge reset_in)
begin
        if(reset_in)
        begin
                way_select_stage <= {(NUMBER_WAYS){1'b0}};
        end
        
        else
        begin
                way_select_stage <= way_select_in;
        end
end

mux_decoded_8
#(.NUMBER_WAYS(NUMBER_WAYS), .SINGLE_ELEMENT_SIZE_IN_BITS(SINGLE_TAG_SIZE_IN_BITS))
mux_8
(
        .way_packed_in    (evict_tag_pack_to_mux),
        .sel_in           (way_select_stage),
        .way_packed_out   (evict_tag_out)
);

endmodule
