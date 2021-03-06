module fifo_queue
#(
        parameter QUEUE_SIZE = 16,
        parameter QUEUE_PTR_WIDTH_IN_BITS = 4,
        parameter SINGLE_ENTRY_WIDTH_IN_BITS = 32,
        parameter STORAGE_TYPE = "LUTRAM"
)
(  
        input                                                                   reset_in,
        input                                                                   clk_in,

        output                                                                  is_empty_out,
        output                                                                  is_full_out,

        input           [SINGLE_ENTRY_WIDTH_IN_BITS - 1 : 0]                    request_in,
        input                                                                   request_valid_in,
        output  reg                                                             issue_ack_out,
                
        output  reg     [SINGLE_ENTRY_WIDTH_IN_BITS - 1 : 0]                    request_out,
        output  reg                                                             request_valid_out,
        input                                                                   issue_ack_in,

        output          [SINGLE_ENTRY_WIDTH_IN_BITS * QUEUE_SIZE - 1 : 0]       fifo_entry_packed_out,
        output          [QUEUE_SIZE - 1 : 0]                                    fifo_entry_valid_packed_out
);

wire [SINGLE_ENTRY_WIDTH_IN_BITS  - 1 : 0] fifo_entry_packed [QUEUE_SIZE - 1 : 0];
wire [QUEUE_SIZE                  - 1 : 0] fifo_entry_valid_packed;

genvar gen;
for(gen = 0; gen < QUEUE_SIZE; gen = gen + 1)
begin
        assign fifo_entry_packed_out[(gen+1) * SINGLE_ENTRY_WIDTH_IN_BITS - 1 : gen * SINGLE_ENTRY_WIDTH_IN_BITS] = fifo_entry_packed[gen];
end

assign fifo_entry_valid_packed_out = fifo_entry_valid_packed;

reg  [QUEUE_PTR_WIDTH_IN_BITS     - 1 : 0] write_ptr;
reg  [QUEUE_PTR_WIDTH_IN_BITS     - 1 : 0] read_ptr;

assign is_full_out  = &fifo_entry_valid_packed;
assign is_empty_out = &(~fifo_entry_valid_packed);

always@(posedge clk_in, posedge reset_in)
begin
        if(reset_in)
        begin
                write_ptr     <= {(QUEUE_PTR_WIDTH_IN_BITS){1'b0}};
                issue_ack_out <= 1'b0;
                read_ptr      <= {(QUEUE_PTR_WIDTH_IN_BITS){1'b0}};
                request_out   <= {(SINGLE_ENTRY_WIDTH_IN_BITS){1'b0}};
                request_valid_out <= 1'b0;
        end

        else
        begin
                // write logic
                // generate write_ptr when the queue is full but the issue_ack_in is high, save 1 cycle
                if((~is_full_out | (issue_ack_in & is_full_out)) & request_valid_in)
                begin
                        write_ptr     <= write_ptr == {(QUEUE_PTR_WIDTH_IN_BITS){1'b1}} ? {(QUEUE_PTR_WIDTH_IN_BITS){1'b0}} : write_ptr + 1'b1;
                        issue_ack_out <= 1'b1;
                end
                
                else 
                begin
                        write_ptr     <= write_ptr;
                        issue_ack_out <= 1'b0;
                end

                // read logic
                if(issue_ack_in & fifo_entry_valid_packed[read_ptr])
                begin
                        read_ptr    <= read_ptr == {(QUEUE_PTR_WIDTH_IN_BITS){1'b1}} ? {(QUEUE_PTR_WIDTH_IN_BITS){1'b0}} : read_ptr + 1'b1;
                        request_out <= fifo_entry_packed[read_ptr];
                        request_valid_out <= 1'b1;
                end
                
                else if(fifo_entry_valid_packed[read_ptr])
                begin
                        read_ptr    <= read_ptr;
                        request_out <= fifo_entry_packed[read_ptr];   
                        request_valid_out <= 1'b1;    
                end
                
                else
                begin
                        read_ptr    <= read_ptr;
                        request_out <= {(SINGLE_ENTRY_WIDTH_IN_BITS){1'b0}};
                        request_valid_out <= 1'b0;
                end
        end
end

generate

if(STORAGE_TYPE == "LUTRAM")

        for(gen = 0; gen < QUEUE_SIZE; gen = gen + 1)
        begin
                reg [SINGLE_ENTRY_WIDTH_IN_BITS  - 1 : 0] entry;
                reg                                       entry_valid;

                assign fifo_entry_packed[gen]        =    entry;
                assign fifo_entry_valid_packed[gen]  =    entry_valid;

                wire write_qualified = (~is_full_out | (issue_ack_in & is_full_out)) & request_valid_in & gen == write_ptr;
                wire read_qualified  = ~is_empty_out & issue_ack_in & entry_valid & gen == read_ptr;

                always @(posedge clk_in, posedge reset_in)
                begin
                        if (reset_in)
                        begin
                                entry       <= {(SINGLE_ENTRY_WIDTH_IN_BITS){1'b0}};
                                entry_valid <= 1'b0;
                        end
                        
                        else
                        begin
                                if(write_qualified & read_qualified)
                                begin
                                        entry       <= request_in;
                                        entry_valid <= 1'b1;
                                end

                                else
                                begin
                                        if(read_qualified)
                                        begin
                                                entry       <= {(SINGLE_ENTRY_WIDTH_IN_BITS){1'b0}};
                                                entry_valid <= 1'b0;
                                        end

                                        else if(write_qualified)
                                        begin
                                                entry       <= request_in;
                                                entry_valid <= 1'b1;
                                        end

                                        else
                                        begin
                                                entry       <= entry;
                                                entry_valid <= entry_valid;   
                                        end
                                end
                        end
                end
        end

endgenerate

endmodule
