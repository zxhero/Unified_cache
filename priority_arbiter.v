module priority_arbiter
#(
        parameter NUM_REQUESTS                 = 3,
        parameter SINGLE_REQUEST_WIDTH_IN_BITS = 64
)
(
        input                                                            reset_in,
        input                                                            clk_in,
    
        input      [SINGLE_REQUEST_WIDTH_IN_BITS * NUM_REQUESTS - 1 : 0] request_packed_in,
        input      [NUM_REQUESTS                                - 1 : 0] request_valid_packed_in,
        input      [NUM_REQUESTS                                - 1 : 0] request_critical_packed_in,
        output reg [NUM_REQUESTS                                - 1 : 0] issue_ack_out,

        output reg [SINGLE_REQUEST_WIDTH_IN_BITS                - 1 : 0] request_out,
        output reg                                                       request_valid_out,
        input                                                            issue_ack_in
);
// vivado 2016.4 doesn't support $ceil function, may add in the future
parameter [31:0] NUM_REQUESTS_LOG2_LOW = $clog2(NUM_REQUESTS);
parameter [31:0] NUM_REQUESTS_LOG2     = 2 ** NUM_REQUESTS_LOG2_LOW < NUM_REQUESTS ? NUM_REQUESTS_LOG2_LOW + 1 : NUM_REQUESTS_LOG2_LOW;

reg [NUM_REQUESTS_LOG2 - 1 : 0] last_send_index;
reg [NUM_REQUESTS      - 1 : 0] ack_to_send;

// separete requests
wire [SINGLE_REQUEST_WIDTH_IN_BITS - 1 : 0] request_packed_separation [NUM_REQUESTS - 1 : 0];

genvar gen;
for(gen = 0; gen < NUM_REQUESTS; gen = gen + 1)
begin
        assign request_packed_separation[gen] = request_packed_in[(gen+1) * SINGLE_REQUEST_WIDTH_IN_BITS - 1 : gen * SINGLE_REQUEST_WIDTH_IN_BITS];
end

// shift the request valid/critical packeded wire
wire [NUM_REQUESTS - 1 : 0] request_valid_packed_shift_left;
wire [NUM_REQUESTS - 1 : 0] request_critical_packed_shift_left;

assign request_valid_packed_shift_left     = (request_valid_packed_in >> last_send_index + 1) | (request_valid_packed_in << (NUM_REQUESTS - last_send_index - 1));
assign request_critical_packed_shift_left  = (request_critical_packed_in >> last_send_index + 1) | (request_critical_packed_in << (NUM_REQUESTS - last_send_index - 1));

// find the first valid requests
reg [NUM_REQUESTS_LOG2 - 1 : 0] valid_sel;
integer                         valid_find_index;

always@*
begin : Find_First_Valid_Way
        valid_sel  <= {(NUM_REQUESTS_LOG2){1'b0}};
        
        for(valid_find_index = 0; valid_find_index < NUM_REQUESTS; valid_find_index = valid_find_index + 1)
        begin
                if(request_valid_packed_shift_left[valid_find_index])
                begin
                        if(last_send_index + valid_find_index + 1 >= NUM_REQUESTS)
                                valid_sel <= last_send_index + valid_find_index + 1 - NUM_REQUESTS;
                        else 
                                valid_sel <= last_send_index + valid_find_index + 1;
                        disable Find_First_Valid_Way; //TO exit the loop
                end
        end
end

// find the first critical requests
reg [NUM_REQUESTS_LOG2 - 1 : 0] critical_sel;
integer                         critical_find_index;

always@*
begin : Find_First_Critical_Way
        critical_sel  <= {(NUM_REQUESTS_LOG2){1'b0}};
        
        for(critical_find_index = 0; critical_find_index < NUM_REQUESTS; critical_find_index = critical_find_index + 1)
        begin
                if(request_critical_packed_shift_left[critical_find_index] & request_valid_packed_shift_left[critical_find_index])
                begin
                        if(last_send_index + critical_find_index + 1 >= NUM_REQUESTS)
                                critical_sel <= last_send_index + critical_find_index + 1 - NUM_REQUESTS;
                        else
                                critical_sel <= last_send_index + critical_find_index + 1;
                        disable Find_First_Critical_Way; //TO exit the loop
                end
        end
end


// fill the valid/critical mask
wire [NUM_REQUESTS - 1 : 0]      valid_mask;
wire [NUM_REQUESTS - 1 : 0]      critical_mask;


for(gen = 0; gen < NUM_REQUESTS; gen = gen + 1)
begin
        assign    valid_mask[gen]      =    valid_sel == gen ? 1 : 0;
        assign critical_mask[gen]      = critical_sel == gen ? 1 : 0; 
end

// arbiter logic
always@(posedge clk_in, posedge reset_in)
begin
        if(reset_in)
        begin
                request_out       <= {(SINGLE_REQUEST_WIDTH_IN_BITS){1'b0}};
                request_valid_out <= {(NUM_REQUESTS){1'b0}};
                ack_to_send       <= {(NUM_REQUESTS){1'b0}};
                issue_ack_out     <= {(NUM_REQUESTS){1'b0}};
                last_send_index   <= {(NUM_REQUESTS_LOG2){1'b0}};
        end

        // move on to the next request
        else if( (issue_ack_in & request_valid_out) | ~request_valid_out)
        begin
                if(request_critical_packed_in[critical_sel] & (|request_critical_packed_in) & request_valid_packed_in[critical_sel] )
                begin
                        request_out       <= request_packed_separation[critical_sel];
                        request_valid_out <= 1'b1;
                        ack_to_send       <= critical_mask;
                        issue_ack_out     <= ack_to_send;
                        last_send_index   <= critical_sel;
                end

                else if(request_valid_packed_in[valid_sel])
                begin
                        request_out       <= request_packed_separation[valid_sel];
                        request_valid_out <= 1'b1;
                        ack_to_send       <= valid_mask;
                        issue_ack_out     <= ack_to_send;
                        last_send_index   <= valid_sel;
                end

                else
                begin
                        request_out       <= {(SINGLE_REQUEST_WIDTH_IN_BITS){1'b0}};
                        request_valid_out <= 1'b0;
                        ack_to_send       <= ack_to_send;
                        issue_ack_out     <= {(NUM_REQUESTS){1'b0}};
                        last_send_index   <= last_send_index;
                end
        end

        else
        begin
                        request_out       <= request_out;
                        request_valid_out <= request_valid_out;
                        ack_to_send       <= ack_to_send;
                        issue_ack_out     <= {(NUM_REQUESTS){1'b0}};
                        last_send_index   <= last_send_index;
        end
end

endmodule
