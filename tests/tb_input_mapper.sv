`timescale 1ns/1ps
module tb_input_mapper;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,begin_mapping=0,reset_mapping=0,running=1,focus=1;
    reg [7:0] physical=0;
    reg start_button=0,select_button=0,machine_sms=1;
    reg [8:0] x=32,y=35;
    wire active;
    wire [2:0] step;
    wire [5:0] mapped;
    wire [11:0] color;
    input_mapper #(.DEBOUNCE_CYCLES(4)) dut(.*);
    mapper_overlay screen(.machine_sms(machine_sms),.step(step),.x(x),.y(y),.color(color));
    task automatic advance(input integer n);
        repeat(n) @(negedge clk);
    endtask
    task automatic release_all;
        begin physical=0;start_button=0;select_button=0;advance(8); end
    endtask
    initial begin
        advance(2); reset=0;
        if(mapped!==6'b0) $fatal(1,"Unexpected mapping with no buttons");
        physical=8'h10; advance(2);
        if(mapped[4]!==1'b1 || mapped[5]!==1'b0) $fatal(1,"Default A/B binding changed");
        release_all();
        begin_mapping=1; advance(1); begin_mapping=0; advance(9);
        if(!active || step!==0) $fatal(1,"On-screen mapper did not start at Up");
        x=33; #1; x=32; #1;
        if(color!==12'hfff) $fatal(1,"Mapper prompt pixel=%h text=%h glyph=%h char=%0d col=%0d row=%0d",
            color,screen.text_char(0,0,step),screen.glyph("M"),screen.character,screen.column,screen.row);
        x=34; #1;
        if(color!==12'h211) $fatal(1,"Mapper prompt glyph spacing incorrect");
        physical=8'h40; advance(8); // X adds a binding for Up.
        if(step!==1) $fatal(1,"X was not captured for Up");
        advance(20);
        if(step!==1) $fatal(1,"Held X repeated a binding");
        release_all();
        select_button=1; advance(8); // Keep default Down.
        if(step!==2) $fatal(1,"Select did not keep Down binding");
        release_all();
        physical=8'h80; advance(8); // Y for Left.
        if(step!==3) $fatal(1,"Y was not captured for Left");
        release_all();
        start_button=1; advance(8);
        if(active) $fatal(1,"Start did not exit mapping");
        release_all();
        physical=8'h40; advance(1);
        if(mapped[0]!==1'b1 || mapped[4]!==1'b0)
            $fatal(1,"Captured X-to-Up binding did not reach virtual buttons");
        physical=8'h80; advance(1);
        if(mapped[2]!==1'b1) $fatal(1,"Captured Y-to-Left binding was lost");
        reset_mapping=1; advance(1); reset_mapping=0; advance(1);
        if(mapped[0]!==0 || mapped[2]!==0) $fatal(1,"Restore controls did not restore defaults");
        $display("PASS on-screen mapper: glyph, capture, keep, exit, restore and default A/B");
        $finish;
    end
    initial begin #100000; $fatal(1,"Mapper test timed out"); end
endmodule
