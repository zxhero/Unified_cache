`define encoder_case(count) { {(NUMBER_WAYS - (count) - 1){1'b0}}, {{1'b1}}, {(count){1'bx}} } : way_packed_out <= data_to_mux[count]

module mux_decoded_8
#(
	 parameter NUMBER_WAYS = 8,
	 parameter SINGLE_ELEMENT_SIZE_IN_BITS = 4
)
(
	input      [SINGLE_ELEMENT_SIZE_IN_BITS * NUMBER_WAYS - 1 : 0] way_packed_in,
	input      [NUMBER_WAYS                               - 1 : 0] sel_in,
	output reg [SINGLE_ELEMENT_SIZE_IN_BITS               - 1 : 0] way_packed_out
);

wire [SINGLE_ELEMENT_SIZE_IN_BITS - 1 : 0] data_to_mux [NUMBER_WAYS - 1 : 0];

generate
    genvar gen;

    for(gen = 0; gen < NUMBER_WAYS; gen = gen + 1)
    begin
    	assign data_to_mux[gen] = way_packed_in[(gen+1) * SINGLE_ELEMENT_SIZE_IN_BITS - 1 : gen * SINGLE_ELEMENT_SIZE_IN_BITS];
    end

endgenerate

integer i;
always@*
begin
	casex(sel_in) 

        `encoder_case(7);
	`encoder_case(6);
	`encoder_case(5);
	`encoder_case(4);
	`encoder_case(3);
	`encoder_case(2);
	`encoder_case(1);
	`encoder_case(0);
	
	default:
	way_packed_out <= {(SINGLE_ELEMENT_SIZE_IN_BITS){1'b0}};
	endcase
end

endmodule
