// SPDX-License-Identifier: GPL-3.0-or-later
// Resolve a ROM's machine without relying on its size or on transfer chunks.
// A loader hint belongs to one load epoch and must precede the first byte.
module sega_rom_type(
    input wire clk,reset,begin_load,finish_load,
    input wire byte_valid,input wire [23:0] byte_address,input wire [7:0] byte_data,
    input wire hint_write,input wire [31:0] hint_value,
    input wire [31:0] committed_length,
    input wire [1:0] system_override, // 0 Auto, 1 GG, 2 SMS
    output wire hint_rejected,
    output reg [1:0] hint_type,
    output reg [1:0] header_type,
    output reg header_conflict,
    output reg [1:0] selected_type,
    output reg [1:0] selected_source // 0 unresolved, 1 override, 2 hint, 3 header
);
    localparam [63:0] SEGA_SIGNATURE=64'h544d522053454741; // "TMR SEGA"
    reg load_active=0,seen_byte=0;
    reg [63:0] signatures[0:2];
    reg [3:0] region_codes[0:2];
    integer i;

    function automatic [1:0] type_from_region(input [3:0] code);
        begin
            case(code)
                4'h3,4'h4: type_from_region=2'd2;
                4'h5,4'h6,4'h7: type_from_region=2'd1;
                default: type_from_region=2'd0;
            endcase
        end
    endfunction

    assign hint_rejected=hint_write &&
        (!load_active || seen_byte || hint_value>32'd2);

    always @(posedge clk) begin
        if(reset || begin_load) begin
            load_active<=!reset;
            seen_byte<=0;
            hint_type<=0;
            for(i=0;i<3;i=i+1) begin
                signatures[i]<=0;
                region_codes[i]<=0;
            end
        end else begin
            if(finish_load) load_active<=0;
            if(hint_write && !hint_rejected) hint_type<=hint_value[1:0];
            if(byte_valid && load_active) begin
                seen_byte<=1;
                if(byte_address>=24'h001ff0 && byte_address<=24'h001ff7)
                    signatures[0]<={signatures[0][55:0],byte_data};
                if(byte_address==24'h001fff) region_codes[0]<=byte_data[7:4];
                if(byte_address>=24'h003ff0 && byte_address<=24'h003ff7)
                    signatures[1]<={signatures[1][55:0],byte_data};
                if(byte_address==24'h003fff) region_codes[1]<=byte_data[7:4];
                if(byte_address>=24'h007ff0 && byte_address<=24'h007ff7)
                    signatures[2]<={signatures[2][55:0],byte_data};
                if(byte_address==24'h007fff) region_codes[2]<=byte_data[7:4];
            end
        end
    end

    reg candidate_seen;
    reg [1:0] candidate_type;
    integer j;
    always @* begin
        candidate_seen=0;
        candidate_type=0;
        header_type=0;
        header_conflict=0;
        for(j=0;j<3;j=j+1) begin
            if(committed_length >= (32'h00002000 << j) &&
               signatures[j]==SEGA_SIGNATURE) begin
                if(!candidate_seen) begin
                    candidate_seen=1;
                    candidate_type=type_from_region(region_codes[j]);
                end else if(candidate_type!=type_from_region(region_codes[j]))
                    header_conflict=1;
            end
        end
        if(candidate_seen && !header_conflict) header_type=candidate_type;
        selected_type=0;
        selected_source=0;
        if(system_override==2'd1 || system_override==2'd2) begin
            selected_type=system_override;
            selected_source=2'd1;
        end else if(hint_type!=0) begin
            selected_type=hint_type;
            selected_source=2'd2;
        end else if(header_type!=0) begin
            selected_type=header_type;
            selected_source=2'd3;
        end
    end
endmodule
