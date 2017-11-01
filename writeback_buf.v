`include "parameters.h"

module writeback_buffer
#(
        parameter QUEUE_SIZE = 16,
        parameter QUEUE_PTR_WIDTH_IN_BITS = 4,
        parameter SINGLE_ENTRY_WIDTH_IN_BITS = 32,
        parameter ADDR_LEN_IN_BITS = `CPU_WORD_LEN_IN_BITS,
        parameter STORAGE_TYPE = "LUTRAM"      
)
(  
        input                                                                   reset_in,
        input                                                                   clk_in,

        output                                                                  is_empty_out,
        output                                                                  is_full_out,

        input           [SINGLE_ENTRY_WIDTH_IN_BITS - 1 : 0]                    request_in,
        input                                                                   request_valid_in,
        output                                                                  issue_ack_out,
                
        output          [SINGLE_ENTRY_WIDTH_IN_BITS - 1 : 0]                    request_out,
        output                                                                  request_valid_out,
        input                                                                   issue_ack_in,

        input           [(ADDR_LEN_IN_BITS) - 1 : 0]                            cam_address_in,
        output          [QUEUE_SIZE - 1 : 0]                                    cam_result_out
);

wire          [SINGLE_ENTRY_WIDTH_IN_BITS * QUEUE_SIZE - 1 : 0]       fifo_entry_packed;
wire          [QUEUE_SIZE - 1 : 0]                                    fifo_entry_valid_packed;

fifo_queue
#
(
        .QUEUE_SIZE(QUEUE_SIZE),
        .QUEUE_PTR_WIDTH_IN_BITS(QUEUE_PTR_WIDTH_IN_BITS),
        .SINGLE_ENTRY_WIDTH_IN_BITS(SINGLE_ENTRY_WIDTH_IN_BITS),
        .STORAGE_TYPE(STORAGE_TYPE)
)
fifo_queue
(
        .clk_in                 (clk_in),
        .reset_in               (reset_in),
        
        .is_empty_out           (is_empty_out),
        .is_full_out            (is_full_out),

        .request_in             (request_in), 
        .request_valid_in       (request_valid_in),
        .issue_ack_out          (issue_ack_out),
        .request_out            (request_out),
        .request_valid_out      (request_valid_out),
        .issue_ack_in           (issue_ack_in),
        .fifo_entry_packed_out  (fifo_entry_packed),
        .fifo_entry_valid_packed_out (fifo_entry_valid_packed)
);

genvar gen;
for(gen = 0; gen < QUEUE_SIZE; gen = gen + 1)
begin
        assign cam_result_out[gen] = (fifo_entry_packed[gen * SINGLE_ENTRY_WIDTH_IN_BITS + (`MEM_PACKET_ADDR_POS_HI) 
                                                           :gen * SINGLE_ENTRY_WIDTH_IN_BITS + (`MEM_PACKET_ADDR_POS_LO)] == cam_address_in)
                                     & fifo_entry_valid_packed[gen];
end

endmodule
