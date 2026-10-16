`timescale 1ns/1ps
module tb_sms_pause_guard;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,machine_sms=0,running=0,focus=0,freeze=0,console_reset=0,start_pressed=1;
    wire pause_pressed;
    integer presses=0;
    sms_pause_guard dut(.*);
    always @(posedge pause_pressed) presses=presses+1;
    task automatic advance(input integer cycles);
        repeat(cycles) @(negedge clk);
    endtask
    task automatic check_press(input integer count,input expected_level);
        begin
            #1;
            if(presses!=count || pause_pressed!==expected_level)
                $fatal(1,"Accepted presses=%0d level=%b expected %0d/%b",
                    presses,pause_pressed,count,expected_level);
        end
    endtask
    initial begin
        advance(2); reset=0; machine_sms=1; running=1; focus=1;
        advance(4); check_press(0,0); // Held GG Start across transition never creates an NMI.
        start_pressed=0; advance(2); check_press(0,0);
        start_pressed=1; advance(2); check_press(1,1);
        advance(30); check_press(1,1); // Held Pause stays low at the native NMI input.
        start_pressed=0; advance(2); check_press(1,0);
        start_pressed=1; advance(2); check_press(2,1);

        focus=0; advance(2); check_press(2,0);
        focus=1; advance(2); check_press(2,0); // Still held when focus returns.
        start_pressed=0; advance(2);
        start_pressed=1; advance(2); check_press(3,1);

        freeze=1; advance(2); check_press(3,0);
        freeze=0; advance(2); check_press(3,0);
        start_pressed=0; advance(2);
        start_pressed=1; advance(2); check_press(4,1);

        console_reset=1; advance(2); check_press(4,0);
        console_reset=0; advance(2); check_press(4,0);
        start_pressed=0; advance(2);
        start_pressed=1; advance(2); check_press(5,1);

        machine_sms=0; advance(2); check_press(5,0);
        machine_sms=1; advance(2); check_press(5,0);
        start_pressed=0; advance(2);
        start_pressed=1; advance(2); check_press(6,1);
        running=0; advance(2); check_press(6,0);
        running=1; advance(2); check_press(6,0);
        $display("PASS SMS Pause: held press, release/repress, GG transition, focus, freeze, Reset, restart");
        $finish;
    end
    initial begin #100000; $fatal(1,"Pause guard test timed out"); end
endmodule
