`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/29/2026 02:41:28 PM
// Design Name: 
// Module Name: temperature_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module temperature_top (
    input  wire       clk,
    input  wire       rst,
    inout  wire       tmp_sda,
    inout  wire       tmp_scl,
    output reg  [6:0] seg,
    output wire       dp,
    output reg  [3:0] an,
    output wire [1:0] led
);

    parameter integer CLK_HZ = 100_000_000;
    parameter integer I2C_HZ = 100_000;
    parameter integer POLL_MS = 250;

    localparam integer HALF = CLK_HZ / (2 * I2C_HZ);
    localparam integer POLL = (CLK_HZ / 1000) * POLL_MS;

    // Open-drain I2C outputs
    reg scl_low, sda_low;
    assign tmp_scl = scl_low ? 1'b0 : 1'bz;
    assign tmp_sda = sda_low ? 1'b0 : 1'bz;

    wire sda_in = tmp_sda;

    // Clock divider
    reg [31:0] div_count, poll_count;
    wire tick = (div_count >= HALF-1);

    // Controller states
    localparam [4:0]
        IDLE=0, ST1=1, ST2=2, ST3=3,
        TS=4, TH=5, TL=6, AH=7, AS=8, AL=9,
        RS1=10, RS2=11, RS3=12, RS4=13,
        RD1=14, RD2=15, RD3=16,
        MA1=17, MA2=18, MA3=19,
        SP1=20, SP2=21, SP3=22;

    reg [4:0] state;
    reg [7:0] tx, rx, high_byte;
    reg [2:0] bit_count;
    reg [1:0] stage;
    reg read_second;

    reg ack_error, error, busy, valid;
    reg [15:0] temp_raw;

    // Temperature conversion: signed 13-bit value,
    // units of 1/16 degree Celsius.
    wire signed [12:0] temp13 = $signed(temp_raw[15:3]);
    reg signed [8:0] temp_c;

    always @(posedge clk) begin
        if (rst)
            temp_c <= 0;
        else if (valid && !error) begin
            if (temp13 >= 0)
                temp_c <= (temp13 + 13'sd8) >>> 4;
            else
                temp_c <= -(((-temp13) + 13'sd8) >>> 4);
        end
    end

    // I2C transaction controller
    always @(posedge clk) begin
        if (rst) begin
            div_count <= 0;
            poll_count <= 0;
            state <= IDLE;
            scl_low <= 0;
            sda_low <= 0;
            tx <= 0;
            rx <= 0;
            high_byte <= 0;
            bit_count <= 0;
            stage <= 0;
            read_second <= 0;
            ack_error <= 0;
            error <= 0;
            busy <= 0;
            valid <= 0;
            temp_raw <= 0;
        end else begin
            if (tick)
                div_count <= 0;
            else
                div_count <= div_count + 1'b1;

            valid <= 0;

            if (state == IDLE) begin
                if (poll_count >= POLL-1)
                    poll_count <= 0;
                else
                    poll_count <= poll_count + 1'b1;
            end else begin
                poll_count <= 0;
            end

            if (tick) begin
                case (state)

                    IDLE: begin
                        scl_low <= 0;
                        sda_low <= 0;
                        busy <= 0;
                        if (poll_count >= POLL-1) begin
                            busy <= 1;
                            error <= 0;
                            ack_error <= 0;
                            stage <= 0;
                            state <= ST1;
                        end
                    end

                    // START
                    ST1: begin
                        scl_low <= 0;
                        sda_low <= 0;
                        state <= ST2;
                    end
                    ST2: begin
                        sda_low <= 1;
                        state <= ST3;
                    end
                    ST3: begin
                        scl_low <= 1;
                        tx <= 8'h96; // 0x4B + write
                        bit_count <= 7;
                        state <= TS;
                    end

                    // Transmit byte
                    TS: begin
                        scl_low <= 1;
                        sda_low <= ~tx[7];
                        state <= TH;
                    end
                    TH: begin
                        scl_low <= 0;
                        state <= TL;
                    end
                    TL: begin
                        scl_low <= 1;
                        if (bit_count == 0) begin
                            sda_low <= 0;
                            state <= AH;
                        end else begin
                            tx <= {tx[6:0],1'b0};
                            bit_count <= bit_count - 1'b1;
                            state <= TS;
                        end
                    end

                    // Slave ACK
                    AH: begin
                        scl_low <= 0;
                        sda_low <= 0;
                        state <= AS;
                    end
                    AS: begin
                        ack_error <= sda_in;
                        state <= AL;
                    end
                    AL: begin
                        scl_low <= 1;
                        if (ack_error) begin
                            error <= 1;
                            state <= SP1;
                        end else begin
                            case (stage)
                                0: begin
                                    stage <= 1;
                                    tx <= 8'h00; // Temp register
                                    bit_count <= 7;
                                    state <= TS;
                                end
                                1: state <= RS1;
                                2: begin
                                    rx <= 0;
                                    bit_count <= 7;
                                    read_second <= 0;
                                    state <= RD1;
                                end
                                default: begin
                                    error <= 1;
                                    state <= SP1;
                                end
                            endcase
                        end
                    end

                    // Repeated START
                    RS1: begin
                        scl_low <= 1;
                        sda_low <= 0;
                        state <= RS2;
                    end
                    RS2: begin
                        scl_low <= 0;
                        state <= RS3;
                    end
                    RS3: begin
                        sda_low <= 1;
                        state <= RS4;
                    end
                    RS4: begin
                        scl_low <= 1;
                        stage <= 2;
                        tx <= 8'h97; // 0x4B + read
                        bit_count <= 7;
                        state <= TS;
                    end

                    // Read byte
                    RD1: begin
                        scl_low <= 1;
                        sda_low <= 0;
                        state <= RD2;
                    end
                    RD2: begin
                        scl_low <= 0;
                        state <= RD3;
                    end
                    RD3: begin
                        rx <= {rx[6:0],sda_in};
                        scl_low <= 1;
                        if (bit_count == 0)
                            state <= MA1;
                        else begin
                            bit_count <= bit_count - 1'b1;
                            state <= RD1;
                        end
                    end

                    // Master ACK after first byte, NACK after second
                    MA1: begin
                        sda_low <= !read_second;
                        scl_low <= 1;
                        state <= MA2;
                    end
                    MA2: begin
                        scl_low <= 0;
                        state <= MA3;
                    end
                    MA3: begin
                        scl_low <= 1;
                        sda_low <= 0;
                        if (!read_second) begin
                            high_byte <= rx;
                            rx <= 0;
                            bit_count <= 7;
                            read_second <= 1;
                            state <= RD1;
                        end else begin
                            temp_raw <= {high_byte,rx};
                            state <= SP1;
                        end
                    end

                    // STOP
                    SP1: begin
                        scl_low <= 1;
                        sda_low <= 1;
                        state <= SP2;
                    end
                    SP2: begin
                        scl_low <= 0;
                        state <= SP3;
                    end
                    SP3: begin
                        sda_low <= 0;
                        busy <= 0;
                        if (!error)
                            valid <= 1;
                        state <= IDLE;
                    end

                    default: begin
                        state <= SP1;
                        error <= 1;
                    end
                endcase
            end
        end
    end

    // Seven-segment multiplexing
    reg [19:0] refresh;
    reg [3:0] digit, ones, tens;
    reg signed [8:0] magnitude;

    always @(posedge clk) begin
        if (rst)
            refresh <= 0;
        else
            refresh <= refresh + 1'b1;
    end

    always @(*) begin
        magnitude = (temp_c < 0) ? -temp_c : temp_c;
        ones = magnitude % 10;
        tens = (magnitude / 10) % 10;

        case (refresh[19:18])
            0: begin an=4'b1110; digit=4'hC; end // C
            1: begin an=4'b1101; digit=ones; end
            2: begin
                an=4'b1011;
                digit=(magnitude < 10) ? 4'hF : tens;
            end
            3: begin
                an=4'b0111;
                digit=(temp_c < 0) ? 4'hA : 4'hF;
            end
            default: begin an=4'b1111; digit=4'hF; end
        endcase

        case (digit)
            0: seg=7'b1000000;
            1: seg=7'b1111001;
            2: seg=7'b0100100;
            3: seg=7'b0110000;
            4: seg=7'b0011001;
            5: seg=7'b0010010;
            6: seg=7'b0000010;
            7: seg=7'b1111000;
            8: seg=7'b0000000;
            9: seg=7'b0010000;
            4'hA: seg=7'b0111111; // minus
            4'hC: seg=7'b1000110; // C
            default: seg=7'b1111111; // blank
        endcase
    end

    assign dp = 1'b1;
    assign led[0] = error;
    assign led[1] = busy;

endmodule

