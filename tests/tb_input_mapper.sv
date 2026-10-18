`timescale 1ns/1ps
module tb_input_mapper;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,begin_mapping=0,reset_mapping=0,running=1,focus=1;
    reg [11:0] physical=0;
    reg machine_sms=1;
    reg [8:0] x=32,y=35;
    wire active;
    wire [3:0] step;
    wire [9:0] mapped;
    wire [11:0] color;
    input_mapper #(.DEBOUNCE_CYCLES(4),.HOLD_CYCLES(24)) dut(.*);
    mapper_overlay screen(.machine_sms(machine_sms),.step(step),.x(x),.y(y),.color(color));
    task automatic advance(input integer n);
        repeat(n) @(negedge clk);
    endtask
    task automatic release_all;
        begin physical=0;advance(10); end
    endtask
    task automatic tap(input [11:0] mask);
        begin physical=mask;advance(10);release_all(); end
    endtask
    task automatic hold(input [11:0] mask);
        begin physical=mask;advance(40);release_all(); end
    endtask
    task automatic begin_ui;
        begin begin_mapping=1;advance(1);begin_mapping=0;release_all(); end
    endtask
    initial begin
        advance(2);reset=0;
        physical=12'h400;advance(2);
        if(mapped[6]!==1 || mapped[4]!==0) $fatal(1,"Start default changed");
        physical=12'h100;advance(2);
        if(mapped[7]!==1 || mapped[8]!==0) $fatal(1,"Crop defaults changed");
        physical=12'h800;advance(2);
        if(mapped[9]!==1) $fatal(1,"Reset default changed");
        release_all();
        focus=0;begin_ui();
        if(!active || step!==0) $fatal(1,"Mapper did not start");
        physical=12'h40;advance(20);focus=1;advance(20);
        if(step!==0) $fatal(1,"Mapping captured menu-close button before release");
        release_all();
        x=33;#1;x=32;#1;
        if(color!==12'hfff) $fatal(1,"Mapper title glyph missing");
        x=34;#1;
        if(color!==12'h211) $fatal(1,"Mapper glyph spacing incorrect");
        tap(12'h40); // X -> Up
        if(step!==1) $fatal(1,"X was not captured for Up");
        hold(12'h100); // Keep Down by holding L
        if(step!==2 || dut.binding[1]!==1) $fatal(1,"Hold did not keep Down");
        tap(12'h80); // Y -> Left
        tap(12'h400); // Start -> Right
        tap(12'h800); // Select -> A
        tap(12'h100); // L -> B
        tap(12'h200); // R -> Start/Pause
        tap(12'h20); // physical B -> Crop Up
        tap(12'h01); // physical Up -> Crop Down
        if(step!==9 || !active) $fatal(1,"Did not reach Reset command");
        tap(12'h10); // physical A -> Reset
        if(active) $fatal(1,"Final binding did not close mapper");
        physical=12'h40;advance(2);
        if(mapped[0]!==1 || mapped[4]!==0) $fatal(1,"X-to-Up binding lost");
        physical=12'h400;advance(2);
        if(mapped[3]!==1 || mapped[6]!==0) $fatal(1,"Start-to-Right binding lost");
        physical=12'h800;advance(2);
        if(mapped[4]!==1 || mapped[9]!==0) $fatal(1,"Select-to-A binding lost");
        physical=12'h100;advance(2);
        if(mapped[5]!==1) $fatal(1,"L-to-B binding lost");
        physical=12'h200;advance(2);
        if(mapped[6]!==1) $fatal(1,"R-to-Start binding lost");
        physical=12'h20;advance(2);
        if(mapped[7]!==1) $fatal(1,"B-to-Crop-Up binding lost");
        physical=12'h01;advance(2);
        if(mapped[8]!==1) $fatal(1,"Up-to-Crop-Down binding lost");
        physical=12'h10;advance(2);
        if(mapped[9]!==1) $fatal(1,"A-to-Reset binding lost");
        release_all();
        begin_ui();
        tap(12'h003); // Invalid multi-button tap must not bind.
        if(step!==0) $fatal(1,"Multi-button tap advanced the mapper");
        hold(12'hc00); // Start+Select exits without remapping Up.
        if(active || dut.binding[0]!==6) $fatal(1,"Exit chord changed binding");
        reset_mapping=1;advance(1);reset_mapping=0;advance(2);
        if(dut.binding[0]!==0 || dut.binding[6]!==10 ||
           dut.binding[7]!==8 || dut.binding[8]!==9 || dut.binding[9]!==11)
            $fatal(1,"Restore controls did not restore defaults");
        $display("PASS mapper: all 12 inputs, ten commands, focus, tap, hold, exit and restore");
        $finish;
    end
    initial begin #100000; $fatal(1,"Mapper test timed out"); end
endmodule
