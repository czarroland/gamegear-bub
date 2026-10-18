`timescale 1ns/1ps
module tb_video_viewport;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,run=0,freeze=0,ce_pix=1,machine_sms=0,tv_pal=0;
    reg overlay_active=0;
    reg [3:0] overlay_step=0;
    reg [7:0] epoch=0;
    reg [11:0] color=12'h456;
    reg native_hblank=1,native_vblank=1;
    wire [3:0] red,green,blue;
    wire data_enable,hblank,vblank,frame_complete,frame_valid;
    wire [8:0] active_width,active_height;
    wire [7:0] completed_epoch;
    wire completed_machine_sms,completed_tv_pal;
    wire [15:0] frame_id;
    integer completions=0;
    gg_video dut(.*);
    always @(posedge clk) if(frame_complete) completions=completions+1;

    task automatic line(input integer width);
        begin
            @(negedge clk); native_hblank=0;
            repeat(width) @(negedge clk);
            native_hblank=1;
            @(negedge clk);
        end
    endtask
    task automatic frame(input integer width,height,bad_first_line);
        integer row;
        begin
            @(negedge clk); native_vblank=0;
            @(negedge clk); // Start in horizontal blank after the VBlank edge.
            for(row=0;row<height;row=row+1)
                line(row==0 && bad_first_line ? width-1 : width);
            native_vblank=1;
            repeat(3) @(negedge clk);
        end
    endtask
    task automatic check(input integer width,height,expected_completions);
        begin
            if(completions!=expected_completions || !frame_valid ||
               active_width!==width || active_height!==height ||
               completed_epoch!==epoch || completed_machine_sms!==machine_sms ||
               completed_tv_pal!==tv_pal)
                $fatal(1,"Descriptor: completions=%0d valid=%b %0dx%0d epoch=%0d mode=%b/%b",
                    completions,frame_valid,active_width,active_height,
                    completed_epoch,completed_machine_sms,completed_tv_pal);
        end
    endtask
    initial begin
        repeat(2) @(negedge clk); reset=0; run=1;
        frame(160,144,0);
        check(160,144,1);
        frame(160,144,1);
        check(160,144,1); // A short line never publishes a new descriptor.

        @(negedge clk); epoch=1; machine_sms=1;
        repeat(3) @(negedge clk);
        if(frame_valid) $fatal(1,"New epoch did not invalidate the GG frame");
        frame(256,192,0); check(256,192,2);
        frame(256,224,0); check(256,224,3);
        tv_pal=1;
        frame(256,240,0); check(256,240,4);
        if(frame_id!==16'd3) $fatal(1,"Frame ID did not advance within the SMS epoch");
        $display("PASS video viewport: GG 160x144, SMS 256x192/224/240, invalid line, epoch flush");
        $finish;
    end
    initial begin #10000000; $fatal(1,"Video viewport test timed out"); end
endmodule
