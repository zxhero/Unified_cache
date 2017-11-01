`include "parameters.h"

module unified_cache
#(
        parameter UNIFIED_CACHE_PACKET_WIDTH_IN_BITS = 100,
        parameter MEM_PACKET_WIDTH_IN_BITS           = 42
)
(
        input                                           reset_in,
        input                                           clk_in,

        // instruction packet
        input   [(UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0]         inst_packet_in,
        output                                                          inst_packet_ack_out,

        output  [(UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0]         inst_packet_out,
        input                                                           inst_packet_ack_in,

        // data packet
        input   [(UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0]         data_packet_in,
        output                                                          data_packet_ack_out,

        output  [(UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0]         data_packet_out,
        input                                                           data_packet_ack_in,

        // to/from mem
        input   [(MEM_PACKET_WIDTH_IN_BITS) - 1 : 0]   from_mem_packet_in,
        output                                          from_mem_packet_ack_out,

        output  [(MEM_PACKET_WIDTH_IN_BITS) - 1 : 0]   to_mem_packet_out,
        input                                           to_mem_packet_ack_in    
);

// receives instruction packets
wire [(`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0] inst_packet_to_arbiter;
wire                                                 inst_packet_valid_to_arbiter;

fifo_queue
#(
        .QUEUE_SIZE                     (`INST_REQUEST_QUEUE_SIZE),
        .QUEUE_PTR_WIDTH_IN_BITS        (`INST_REQUEST_QUEUE_PTR_WIDTH_IN_BITS),
        .SINGLE_ENTRY_WIDTH_IN_BITS     (`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS)
)
inst_request_queue
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .is_empty_out                   (), // intened left unconnected
        .is_full_out                    (is_inst_request_queue_full),

        .request_in                     (inst_packet_in),
        .request_valid_in               (inst_packet_in[`UNIFIED_CACHE_PACKET_VALID_POS]),
        .issue_ack_out                  (inst_packet_ack_out),
        .request_out                    (inst_packet_to_arbiter),
        .request_valid_out              (inst_packet_valid_to_arbiter),
        .issue_ack_in                   (packet_ack_to_inst_request_queue),
        .fifo_entry_packed_out          (), // intened left unconnected
        .fifo_entry_valid_packed_out    ()  // intened left unconnected
);

// receive data packet
wire [(`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0] data_packet_to_arbiter;
wire                                                 data_packet_valid_to_arbiter;

fifo_queue
#(
        .QUEUE_SIZE                     (`DATA_REQUEST_QUEUE_SIZE),
        .QUEUE_PTR_WIDTH_IN_BITS        (`DATA_REQUEST_QUEUE_PTR_WIDTH_IN_BITS),
        .SINGLE_ENTRY_WIDTH_IN_BITS     (`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS)
)
data_request_queue
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .is_empty_out                   (),  // intened left unconnected
        .is_full_out                    (is_data_request_queue_full),

        .request_in                     (data_packet_in),
        .request_valid_in               (data_packet_in[`UNIFIED_CACHE_PACKET_VALID_POS]),
        .issue_ack_out                  (data_packet_ack_out),
        .request_out                    (data_packet_to_arbiter),
        .request_valid_out              (data_packet_valid_to_arbiter),
        .issue_ack_in                   (packet_ack_to_data_request_queue),
        .fifo_entry_packed_out          (), // intened left unconnected
        .fifo_entry_valid_packed_out    ()  // intened left unconnected
);

// arbiter
wire [(`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0] access_packet_from_arbiter;
wire packet_ack_to_arbiter;


priority_arbiter
#(.NUM_REQUESTS(2), .SINGLE_REQUEST_WIDTH_IN_BITS(`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS))
input_requests_arbiter
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        // the arbiter considers priority from right(high) to left(low)
        .request_packed_in              ({data_packet_to_arbiter, inst_packet_to_arbiter }),
        .request_valid_packed_in        ({data_packet_valid_to_arbiter, inst_packet_valid_to_arbiter}),
        .request_critical_packed_in     ({is_data_request_queue_full, is_inst_request_queue_full}),
        .issue_ack_out                  ({packet_ack_to_data_request_queue, packet_ack_to_inst_request_queue}),
        
        .request_out                    (access_packet_from_arbiter),
        .request_valid_out              (),
        .issue_ack_in                   ()
);

// tag array
wire [((`UNIFIED_CACHE_TAG_POS_HI) - (`UNIFIED_CACHE_TAG_POS_LO))*(`UNIFIED_CACHE_SET_ASSOCIATIVITY)-1:0] access_packet_from_tag;
wire [(`UNIFIED_CACHE_TAG_POS_HI) - (`UNIFIED_CACHE_TAG_POS_LO)-1:0] access_evict_tag;
unified_cache_tag_array
#(
        .SINGLE_TAG_SIZE_IN_BITS        ((`UNIFIED_CACHE_TAG_POS_HI) - (`UNIFIED_CACHE_TAG_POS_LO)+1),
        .NUMBER_WAYS                    (`UNIFIED_CACHE_SET_ASSOCIATIVITY),
        .NUMBER_SETS                    (`UNIFIED_CACHE_NUM_SETS),
        .SET_PTR_WIDTH_IN_BITS          (`UNIFIED_CACHE_INDEX_LEN_IN_BITS)
)
tag_array
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .way_select_in                  (access_tag_way_select),

        .read_en_in                     (tag_read_en),
        .read_set_addr_in               (access_tag_read_set_addr),
        .read_tag_pack_out              (access_packet_from_tag),

        .write_en_in                    (tag_write_en),
        .write_set_addr_in              (access_tag_write_set_addr),
        
        .write_tag_in                   (access_tag_write),
        .evict_tag_out                  (access_evict_tag)
);

// valid array
wire [(`UNIFIED_CACHE_SET_ASSOCIATIVITY)-1:0] access_packet_from_valid;
unified_cache_tag_array
#(
        .SINGLE_TAG_SIZE_IN_BITS        (1),
        .NUMBER_WAYS                    (`UNIFIED_CACHE_SET_ASSOCIATIVITY),
        .NUMBER_SETS                    (`UNIFIED_CACHE_NUM_SETS),
        .SET_PTR_WIDTH_IN_BITS          (`UNIFIED_CACHE_INDEX_LEN_IN_BITS)
)
valid_array
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .way_select_in                  (access_tag_way_select),

        .read_en_in                     (tag_read_en),
        .read_set_addr_in               (access_tag_read_set_addr),
        .read_tag_pack_out              (access_packet_from_valid),

        .write_en_in                    (tag_write_en),
        .write_set_addr_in              (access_tag_write_set_addr),
        
        .write_tag_in                   (access_valid_write),
        .evict_tag_out                  ()
);

// history array
wire [(`UNIFIED_CACHE_SET_ASSOCIATIVITY)-1:0] access_packet_from_history;
unified_cache_tag_array
#(
        .SINGLE_TAG_SIZE_IN_BITS        (1),
        .NUMBER_WAYS                    (`UNIFIED_CACHE_SET_ASSOCIATIVITY),
        .NUMBER_SETS                    (`UNIFIED_CACHE_NUM_SETS),
        .SET_PTR_WIDTH_IN_BITS          (`UNIFIED_CACHE_INDEX_LEN_IN_BITS)
)
history_array
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .way_select_in                  (access_tag_way_select),

        .read_en_in                     (tag_read_en),
        .read_set_addr_in               (access_tag_read_set_addr),
        .read_tag_pack_out              (access_packet_from_history),

        .write_en_in                    (tag_write_en),
        .write_set_addr_in              (access_tag_write_set_addr),
        
        .write_tag_in                   (access_history_write),
        .evict_tag_out                  ()
);

wire [(`UNIFIED_CACHE_BLOCK_SIZE_IN_BITS)-1:0] access_data_read;
unified_cache_data_array
#(
        .CACHE_BLOCK_SIZE_IN_BITS       (`UNIFIED_CACHE_BLOCK_SIZE_IN_BITS),
        .NUMBER_WAYS                    (`UNIFIED_CACHE_SET_ASSOCIATIVITY),
        .NUMBER_SETS                    (`UNIFIED_CACHE_NUM_SETS),
        .SET_PTR_WIDTH_IN_BITS          (`UNIFIED_CACHE_INDEX_LEN_IN_BITS)
)
data_array
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .way_select_in                  (access_data_way_select),
        .access_en_in                   (data_read_en),
        .write_en_in                    (data_write_en),
        .access_set_addr_in             (access_data_set_addr),
    
        .read_data_out                  (access_data_read),
        .write_data_in                  (access_data_write)
);

wire writeback_full;
wire ack_from_writeback_buffer;
wire [(`MEM_PACKET_WIDTH_IN_BITS)-1] requst_from_writeback_buffer;
wire request_valid_from_writeback_buffer;
wire cam_result;
writeback_buffer
#(
        .QUEUE_SIZE                     (`WRITEBACK_BUFFER_SIZE),
        .QUEUE_PTR_WIDTH_IN_BITS        (`WRITEBACK_BUFFER_PTR_WIDTH_IN_BITS),
        .SINGLE_ENTRY_WIDTH_IN_BITS     (`MEM_PACKET_WIDTH_IN_BITS),
        .ADDR_LEN_IN_BITS               (`CPU_WORD_LEN_IN_BITS),
        .STORAGE_TYPE                   ("LUTRAM")
)
writeback_buffer
(  
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .is_empty_out                   (), // intened left unconnected
        .is_full_out                    (writeback_full),

        .request_in                     (writeback_packet_from_ctrl),
        .request_valid_in               (writeback_valid),
        .issue_ack_out                  (ack_from_writeback_buffer),
                
        .request_out                    (requst_from_writeback_buffer),
        .request_valid_out              (request_valid_from_writeback_buffer),
        .issue_ack_in                   (ack_to_writeback_buffer),
        
        .cam_address_in                 (writeback_cam_ad),
        .cam_result_out                 (cam_result)
);

wire inst_return_queue_full;
wire ack_form_inst_return_queue;
fifo_queue
#(
        .QUEUE_SIZE                     (`INST_REQUEST_QUEUE_SIZE),
        .QUEUE_PTR_WIDTH_IN_BITS        (`INST_REQUEST_QUEUE_PTR_WIDTH_IN_BITS),
        .SINGLE_ENTRY_WIDTH_IN_BITS     (`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS)
)
inst_return_queue
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .is_empty_out                   (), // intened left unconnected
        .is_full_out                    (inst_return_queue_full),

        .request_in                     (inst_packet_from_ctrl),
        .request_valid_in               (inst_return_valid),
        .issue_ack_out                  (ack_form_inst_return_queue),
        .request_out                    (inst_packet_out),
        .request_valid_out              (inst_packet_ack_out),
        .issue_ack_in                   (inst_packet_ack_in),
        .fifo_entry_packed_out          (), // intened left unconnected
        .fifo_entry_valid_packed_out    ()  // intened left unconnected
);

wire data_return_queue_full;
wire ack_from_data_return_queue;
fifo_queue
#(
        .QUEUE_SIZE                     (`DATA_REQUEST_QUEUE_SIZE),
        .QUEUE_PTR_WIDTH_IN_BITS        (`DATA_REQUEST_QUEUE_PTR_WIDTH_IN_BITS),
        .SINGLE_ENTRY_WIDTH_IN_BITS     (`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS)
)
data_return_queue
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .is_empty_out                   (),  // intened left unconnected
        .is_full_out                    (data_return_queue_full),

        .request_in                     (data_packet_from_ctrl),
        .request_valid_in               (data_return_valid),
        .issue_ack_out                  (ack_from_data_return_queue),
        .request_out                    (data_packet_out),
        .request_valid_out              (data_packet_ack_out),
        .issue_ack_in                   (data_packet_ack_in),
        .fifo_entry_packed_out          (), // intened left unconnected
        .fifo_entry_valid_packed_out    ()  // intened left unconnected
);

priority_arbiter
#(.NUM_REQUESTS(2), .SINGLE_REQUEST_WIDTH_IN_BITS(`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS))
mem_requests_arbiter
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        // the arbiter considers priority from right(high) to left(low)
        .request_packed_in              ({mem_request_packet,requst_from_writeback_buffer}),
        .request_valid_packed_in        ({mem_request_packet_valid,request_valid_from_writeback_buffer}),
        .request_critical_packed_in     ({mem_request_queue_full,writeback_full}),
        .issue_ack_out                  ({ack_to_mem_requst_queue,ack_to_writeback_buffer}),
        
        .request_out                    (to_mem_packet_out),
        .request_valid_out              (),
        .issue_ack_in                   (to_mem_packet_ack_in)
);

wire mem_request_queue_full;
wire ack_form_mem_request_queue;
wire [(`MEM_PACKET_WIDTH_IN_BITS)-1:0] mem_request_packet;
wire mem_request_packet_valid;
fifo_queue
#(
        .QUEUE_SIZE                     (`WRITEBACK_BUFFER_SIZE),
        .QUEUE_PTR_WIDTH_IN_BITS        (`WRITEBACK_BUFFER_PTR_WIDTH_IN_BITS),
        .SINGLE_ENTRY_WIDTH_IN_BITS     (`MEM_PACKET_WIDTH_IN_BITS)
)
mem_request_queue
(
        .reset_in                       (reset_in),
        .clk_in                         (clk_in),

        .is_empty_out                   (), // intened left unconnected
        .is_full_out                    (mem_request_queue_full),

        .request_in                     (mem_packet_from_ctrl),
        .request_valid_in               (mem_valid),
        .issue_ack_out                  (ack_form_mem_request_queue),
        .request_out                    (mem_request_packet),
        .request_valid_out              (mem_request_packet_valid),
        .issue_ack_in                   (ack_to_mem_requst_queue),
        .fifo_entry_packed_out          (), // intened left unconnected
        .fifo_entry_valid_packed_out    ()  // intened left unconnected
);

wire [(`UNIFIED_CACHE_SET_ASSOCIATIVITY)-1:0] access_tag_way_select;
wire tag_read_en;
wire [(`UNIFIED_CACHE_INDEX_LEN_IN_BITS)-1:0] access_tag_read_set_addr;

wire tag_write_en;
wire [(`UNIFIED_CACHE_INDEX_LEN_IN_BITS)-1:0] access_tag_write_set_addr;
wire [(`UNIFIED_CACHE_TAG_LEN_IN_BITS)-1:0] access_tag_write;

wire [(`UNIFIED_CACHE_SET_ASSOCIATIVITY)-1:0] access_data_way_select;
wire data_read_en;
wire [(`UNIFIED_CACHE_INDEX_LEN_IN_BITS)-1:0] access_data_set_addr;

wire data_write_en;
wire [(`UNIFIED_CACHE_BLOCK_SIZE_IN_BITS)-1:0] access_data_write;

wire [(`UNIFIED_CACHE_SET_ASSOCIATIVITY)-1:0] access_history_write;

wire [(`UNIFIED_CACHE_SET_ASSOCIATIVITY)-1:0] access_valid_write;

wire [(`MEM_PACKET_WIDTH_IN_BITS)-1:0] writeback_packet_from_ctrl;
wire writeback_valid;
wire [(`CPU_WORD_LEN_IN_BITS)-1:0] writeback_cam_ad;

wire [(`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0] inst_packet_from_ctrl;
wire inst_return_valid;

wire [(`UNIFIED_CACHE_PACKET_WIDTH_IN_BITS) - 1 : 0] data_packet_from_ctrl;
wire data_return_valid;

wire [(`MEM_PACKET_WIDTH_IN_BITS)-1:0] mem_packet_from_ctrl;
wire mem_valid;

main_ctrl
#(
        .SINGLE_TAG_SIZE_IN_BITS        (`UNIFIED_CACHE_TAG_LEN_IN_BITS),// parameter list
		.CACHE_BLOCK_SIZE_IN_BITS       (`UNIFIED_CACHE_BLOCK_SIZE_IN_BITS),
		.NUMBER_WAYS                    (`UNIFIED_CACHE_SET_ASSOCIATIVITY),
		.NUMBER_SETS                    (`UNIFIED_CACHE_NUM_SETS);
		.SET_PTR_WIDTH_IN_BITS          (`UNIFIED_CACHE_INDEX_LEN_IN_BITS)
)
(
        .reset_in                       (reset_in),// port list
		.clk_in                         (clk_in),
		.request_in                     (access_packet_from_arbiter),
		.tag_way_select_out             (access_tag_way_select),
		.tag_read_en_out                (tag_read_en),
		.tag_read_set_addr_out          (access_tag_read_set_addr),
		.tag_read_pack_in               (access_packet_from_tag),
		.tag_write_en_out               (tag_write_en),
		.tag_write_set_addr_out         (access_tag_write_set_addr),
		.tag_write_out                  (access_tag_write),
		.tag_evict_in                   (access_evict_tag),
		.data_way_select_out            (access_data_way_select),
		.data_read_en_out               (data_read_en),
		.data_set_addr_out              (access_data_set_addr),
		.data_read_data_in              (access_data_read),
		.data_write_en_out              (data_write_en),
		.data_write_out                 (access_data_write),
		.history_write_out              (access_history_write),
		.history_read_pack_in           (access_packet_from_history),
		.valid_write_out                (access_valid_write),
		.valid_read_pack_in             (access_packet_from_valid),
		.writeback_requst               (writeback_packet_from_ctrl),
		.writeback_valid                (writeback_valid),
		.cam_address                    (writeback_cam_ad),
		.cam_result                     (cam_result),
		.ack_from_writeback_buffer      (ack_from_writeback_buffer),
		.writeback_buffer_full          (writeback_full),
		.inst_return_requst             (inst_packet_from_ctrl),
		.inst_return_valid              (inst_return_valid),
		.inst_return_queue_full         (inst_return_queue_full),
		.ack_form_inst_return_queue     (ack_form_inst_return_queue),
		.data_return_requst             (data_packet_from_ctrl),
		.data_return_valid              (data_return_valid),
		.data_return_queue_full         (data_return_queue_full),
		.ack_from_data_return_queue     (ack_from_data_return_queue),
		.mem_request                    (mem_packet_from_ctrl),
		.mem_valid                      (mem_valid),
		.ack_from_mem_request_queue     (ack_form_mem_request_queue),
		.mem_request_queue_full         (mem_request_queue_full),
		.mem_packet                     (from_mem_packet_in),
		.from_mem_packet_ack_out        (from_mem_packet_ack_out)
);

endmodule

