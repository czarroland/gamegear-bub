// SPDX-License-Identifier: GPL-3.0-or-later
// Native-resolution on-screen prompt for the ten sequential command bindings.
module mapper_overlay(
    input wire machine_sms,
    input wire [3:0] step,
    input wire [8:0] x,y,
    output reg [11:0] color
);
    function automatic [7:0] text_char(input [1:0] line,input [3:0] index,input [3:0] stage);
        reg [127:0] row;
        begin
            case(line)
                0: row="MAP CONTROLS    ";
                1: case(stage)
                    0: row="PRESS FOR UP    ";
                    1: row="PRESS FOR DOWN  ";
                    2: row="PRESS FOR LEFT  ";
                    3: row="PRESS FOR RIGHT ";
                    4: row="PRESS FOR A     ";
                    5: row="PRESS FOR B     ";
                    6: row="PRESS START     ";
                    7: row="PRESS CROP UP   ";
                    8: row="PRESS CROP DOWN ";
                    default: row="PRESS RESET     ";
                endcase
                2: row="HOLD 1S KEEP    ";
                default: row="START+SEL EXIT  ";
            endcase
            text_char=row[8*(15-index)+:8];
        end
    endfunction
    function automatic [34:0] glyph(input [7:0] c);
        case(c)
            "A": glyph=35'b01110_10001_10001_11111_10001_10001_10001;
            "B": glyph=35'b11110_10001_10001_11110_10001_10001_11110;
            "C": glyph=35'b01111_10000_10000_10000_10000_10000_01111;
            "D": glyph=35'b11110_10001_10001_10001_10001_10001_11110;
            "E": glyph=35'b11111_10000_10000_11110_10000_10000_11111;
            "F": glyph=35'b11111_10000_10000_11110_10000_10000_10000;
            "G": glyph=35'b01111_10000_10000_10111_10001_10001_01111;
            "H": glyph=35'b10001_10001_10001_11111_10001_10001_10001;
            "I": glyph=35'b11111_00100_00100_00100_00100_00100_11111;
            "J": glyph=35'b00111_00010_00010_00010_10010_10010_01100;
            "K": glyph=35'b10001_10010_10100_11000_10100_10010_10001;
            "L": glyph=35'b10000_10000_10000_10000_10000_10000_11111;
            "M": glyph=35'b10001_11011_10101_10101_10001_10001_10001;
            "N": glyph=35'b10001_11001_10101_10011_10001_10001_10001;
            "O": glyph=35'b01110_10001_10001_10001_10001_10001_01110;
            "P": glyph=35'b11110_10001_10001_11110_10000_10000_10000;
            "Q": glyph=35'b01110_10001_10001_10001_10101_10010_01101;
            "R": glyph=35'b11110_10001_10001_11110_10100_10010_10001;
            "S": glyph=35'b01111_10000_10000_01110_00001_00001_11110;
            "T": glyph=35'b11111_00100_00100_00100_00100_00100_00100;
            "U": glyph=35'b10001_10001_10001_10001_10001_10001_01110;
            "V": glyph=35'b10001_10001_10001_10001_10001_01010_00100;
            "W": glyph=35'b10001_10001_10001_10101_10101_10101_01010;
            "X": glyph=35'b10001_10001_01010_00100_01010_10001_10001;
            "Y": glyph=35'b10001_10001_01010_00100_00100_00100_00100;
            "Z": glyph=35'b11111_00001_00010_00100_01000_10000_11111;
            "1": glyph=35'b00100_01100_00100_00100_00100_00100_01110;
            "+": glyph=35'b00100_00100_00100_11111_00100_00100_00100;
            default: glyph=35'd0;
        endcase
    endfunction
    reg [1:0] line;
    reg [8:0] font_x,font_y;
    reg [3:0] character;
    reg [2:0] column,row;
    reg [34:0] bits;
    reg text_area;
    always @* begin
        color=12'h211; // Dark blue backing hides the live game under the prompt.
        if(x==9'd24 || x==9'd231 || y==9'd16 || y==(machine_sms ? 9'd165 : 9'd125))
            color=12'hfff;
        line=0; font_x=0; font_y=0; character=0; column=0; row=0;
        bits=0; text_area=0;
        if(x>=9'd32 && x< (machine_sms ? 9'd224 : 9'd128)) begin
            if(machine_sms) begin
                font_x=(x-9'd32)>>1;
                if(y>=9'd35 && y<9'd49) begin line=0; font_y=(y-9'd35)>>1; text_area=1; end
                else if(y>=9'd68 && y<9'd82) begin line=1; font_y=(y-9'd68)>>1; text_area=1; end
                else if(y>=9'd110 && y<9'd124) begin line=2; font_y=(y-9'd110)>>1; text_area=1; end
                else if(y>=9'd135 && y<9'd149) begin line=3; font_y=(y-9'd135)>>1; text_area=1; end
            end else begin
                font_x=x-9'd32;
                if(y>=9'd28 && y<9'd35) begin line=0; font_y=y-9'd28; text_area=1; end
                else if(y>=9'd52 && y<9'd59) begin line=1; font_y=y-9'd52; text_area=1; end
                else if(y>=9'd82 && y<9'd89) begin line=2; font_y=y-9'd82; text_area=1; end
                else if(y>=9'd100 && y<9'd107) begin line=3; font_y=y-9'd100; text_area=1; end
            end
        end
        if(text_area) begin
            character=font_x/6;
            column=font_x%6;
            row=font_y[2:0];
            bits=glyph(text_char(line,character,step));
            if(character<16 && column<5 && row<7 && bits[34-(row*5+column)])
                color=(line==1) ? 12'h0ff : 12'hfff;
        end
    end
endmodule
