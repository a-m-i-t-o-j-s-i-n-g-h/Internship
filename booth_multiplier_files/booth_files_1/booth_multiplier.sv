module booth_multiplier #(
    parameter int DATAWIDTH = 8
)(
    input  logic                        clk,
    input  logic                        rst_vals,
    input  logic                        rst_overall,
    input  logic                        start,
    input  logic signed [DATAWIDTH-1:0] a,       // Multiplicand
    input  logic signed [DATAWIDTH-1:0] b,       // Multiplier
    output logic signed [2*DATAWIDTH-1:0] product,
    output logic                        done
);

    // Internal registers
    logic signed [DATAWIDTH:0] acc;   // Accumulator with extra bit
    logic signed [DATAWIDTH:0] m;     // Multiplicand extended
    logic signed [DATAWIDTH:0] q;     // Multiplier extended (with extra bit)
    integer count;

    typedef enum logic [1:0] {IDLE, RUN, FINISH} state_t;
    state_t state, next_state;

    // Sequential state machine
    always_ff @(posedge clk or posedge rst_vals or posedge rst_overall) begin
        if (rst_vals || rst_overall) begin
            state   <= IDLE;
            acc     <= '0;
            m       <= '0;
            q       <= '0;
            count   <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: if (start) begin
                          acc   <= '0;
                          m     <= {a[DATAWIDTH-1], a};   // sign-extend
                          q     <= {b, 1'b0};             // append extra bit
                          count <= DATAWIDTH;
                      end

                RUN: if (count > 0) begin
                    logic signed [DATAWIDTH:0] acc_temp;

                        case (q[1:0])
                            2'b01: acc_temp = acc + m;
                            2'b10: acc_temp = acc - m;
                            default: acc_temp = acc;
                        endcase

                    acc   <= acc_temp >>> 1;
                    q     <= {acc_temp[0], q[DATAWIDTH:1]};
                    count <= count - 1;
                end
            endcase
        end
    end

    // Next-state logic
    always_comb begin
        next_state = state;
          // default

        case (state)
            IDLE:   begin done       = 1'b0; 
                product = 0;
            if (start) next_state = RUN; end
            RUN:    if (count == 0) next_state = FINISH;
            FINISH: begin
                        done = 1'b1;
                        product = {acc[DATAWIDTH-1:0], q[DATAWIDTH:1]};
                        if (!start) next_state = IDLE;
                    end
        endcase
    end

endmodule
