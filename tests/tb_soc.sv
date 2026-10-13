`timescale 1ns/1ps
module tb_soc;
    `include "diagnostics/diagnostic_crc.vh"
    reg clk=0; always #10 clk=~clk;
    reg reset=1;
    reg [6:0] buttons=0;
    reg mem_enable=0,mem_write=0,command_request=0;
    reg [31:0] mem_address=0,mem_data_write=0;
    wire mem_done,command_busy,command_done,command_error;
    wire [31:0] mem_data_read;
    wire memory_request,memory_write,memory_ready,memory_done,memory_initialized;
    wire [24:0] memory_address;
    wire [7:0] memory_data_write,memory_data_read;
    wire [3:0] red,green,blue;
    wire data_enable,hblank,vblank;
    wire [1:0] display_scale_mode;
    wire signed [15:0] audio_left,audio_right;
    wire cke,cs,ras,cas,we,data_dir;
    wire [1:0] dqm,bank;
    wire [12:0] sa;
    wire [15:0] data_in,data_out;
    wire [31:0] refreshes;
    gamegear_soc dut(.*);
    gg_sdram #(.INIT_CYCLES(20)) memory(.clk(clk),.reset(reset),.request(memory_request),
        .write(memory_write),.address(memory_address),.data_write(memory_data_write),
        .ready(memory_ready),.done(memory_done),.data_read(memory_data_read),.initialized(memory_initialized),
        .cke(cke),.cs(cs),.ras(ras),.cas(cas),.we(we),.dqm(dqm),.bank(bank),.sdram_address(sa),
        .data_in(data_in),.data_out(data_out),.data_dir(data_dir));
    sdram_model model(~clk,cke,cs,ras,cas,we,bank,dqm,sa,data_out,data_dir,data_in,refreshes);
    reg [7:0] rom[0:65535];
    reg [31:0] result;
    integer i,timeout;
    task host(input wr,input [31:0] address,input [31:0] data,input keep_enable);
        integer cycles;
        begin
            @(negedge clk); mem_enable=1; mem_write=wr; mem_address=address; mem_data_write=data;
            cycles=0;
            while(!mem_done) begin
                @(negedge clk); cycles=cycles+1;
                if(cycles>1000) $fatal(1,"Host access timeout at %h",address);
            end
            if(cycles<2) $fatal(1,"Host done arrived too early");
            result=mem_data_read;
            if(!keep_enable) mem_enable=0;
        end
    endtask
    task command(input [15:0] opcode,input [31:0] arg1,arg2,arg3,input expect_error);
        integer cycles;
        reg saved_error;
        begin
            host(1,32'hf0000000,{16'd0,opcode},0);
            host(1,32'hf0000004,arg1,0); host(1,32'hf0000008,arg2,0); host(1,32'hf000000c,arg3,0);
            @(negedge clk); command_request=1; cycles=0;
            while(!command_done) begin
                @(negedge clk); cycles=cycles+1;
                if(cycles>100000) $fatal(1,"Command timeout %h",opcode);
            end
            if(command_error!==expect_error) $fatal(1,"Command %h error=%b expected=%b code=%0d",opcode,command_error,expect_error,dut.last_error);
            saved_error=command_error;
            repeat(4) begin
                @(negedge clk);
                if(!command_done || command_error!==saved_error) $fatal(1,"Command response not held");
            end
            host(0,32'hf0000000,0,0);
            command_request=0;
            @(negedge clk);
            if(command_done || command_error || command_busy) $fatal(1,"Command did not return idle");
        end
    endtask
    task expect_read(input [31:0] address,expected);
        begin host(0,address,0,0); if(result!==expected) $fatal(1,"Read[%h]=%h expected %h",address,result,expected); end
    endtask
    integer frames=0,pixels=0,line_pixels=0,rows=0,total_red=0,total_green=0,fd=0,cycle=0,last_frame_cycle=0;
    reg previous_de=0,previous_hblank=1,previous_vblank=1,check_frames=0,capture=0;
    always @(negedge clk) begin
        cycle=cycle+1;
        if(reset) begin previous_de=0; previous_hblank=1; previous_vblank=1; end
        else begin
            if(data_enable && previous_de) $fatal(1,"Duplicate system-cycle pixel enables");
            if(data_enable && (hblank || vblank)) $fatal(1,"Pixel in blanking");
            if(check_frames) begin
                if(!vblank && previous_vblank) begin pixels=0;rows=0;line_pixels=0; end
                if(data_enable) begin
                    pixels=pixels+1; line_pixels=line_pixels+1;
                    if({blue,green,red}==12'h00f) total_red=total_red+1;
                    if({blue,green,red}==12'h0f0) total_green=total_green+1;
                    if(capture) $fwrite(fd,"%c%c%c",red*17,green*17,blue*17);
                end
                if(hblank && !previous_hblank && line_pixels!=0) begin
                    if(line_pixels!=160) $fatal(1,"Line has %0d pixels",line_pixels);
                    line_pixels=0;rows=rows+1;
                end
                if(vblank && !previous_vblank) begin
                    if(pixels!=23040 || rows!=144) $fatal(1,"Frame=%0d pixels/%0d rows",pixels,rows);
                    frames=frames+1;
                    if(last_frame_cycle!=0 && cycle-last_frame_cycle!=342*262*10)
                        $fatal(1,"Native frame cadence changed: %0d cycles",cycle-last_frame_cycle);
                    last_frame_cycle=cycle;
                    if(capture) begin $fclose(fd);capture=0; end
                end
                if(!vblank && previous_vblank && frames==2) begin
                    fd=$fopen("build/diagnostic-frame.ppm","wb");
                    $fwrite(fd,"P6\n160 144\n255\n");capture=1;
                end
            end
            previous_de=data_enable;previous_hblank=hblank;previous_vblank=vblank;
        end
    end
    reg [229:0] frozen_cpu;
    integer refresh_before;
    initial begin
        $readmemh("diagnostics/gamegear-diagnostic.hex",rom);
        repeat(5) @(negedge clk); reset=0;
        wait(memory_initialized); @(negedge clk);
        if(display_scale_mode!==0) $fatal(1,"Default screen scale must be 3x");
        expect_read(32'h1c,0);
        host(1,32'h1c,1,0);
        expect_read(32'h1c,1);
        if(display_scale_mode!==1) $fatal(1,"2x scale control did not change");
        host(1,32'h1c,2,0);
        expect_read(32'h1c,2);
        if(display_scale_mode!==2) $fatal(1,"4x scale control did not change");
        host(1,32'h1c,0,0);
        expect_read(32'h1c,0);
        if(display_scale_mode!==0) $fatal(1,"3x scale control did not restore");
        command(0,0,0,0,0); if(result!==2) $fatal(1,"Not in SETUP");
        command(16'h0100,0,0,0,1); // Cannot run before ROM/setup.
        command(16'h0102,0,0,0,0);
        command(16'h0300,0,0,0,0);
        for(i=0;i<65536;i=i+4) host(1,32'h30000000+i,{rom[i+3],rom[i+2],rom[i+1],rom[i]},1);
        mem_enable=0;
        command(16'h0301,0,65532,0,1); // Length mismatch must not start.
        command(16'h0300,0,0,0,0); // Reload after failed import.
        for(i=0;i<65536;i=i+4) host(1,32'h30000000+i,{rom[i+3],rom[i+2],rom[i+1],rom[i]},1);
        mem_enable=0;
        command(16'h0301,0,65536,0,0);
        expect_read(32'h100,65536); expect_read(32'h104,65536);
        expect_read(32'h108,DIAGNOSTIC_CRC);
        command(16'h0300,1,0,0,0);
        host(1,32'h40000000,32'h44332211,0);
        command(16'h0301,1,4,0,0);
        command(16'h0200,1,0,0,0); command(16'h0100,0,0,0,0);
        command(0,0,0,0,0); if(result!==4) $fatal(1,"Not RUNNING");
        repeat(400000) @(negedge clk);
        expect_read(32'h41000000,32'h5a334747); expect_read(32'h41000004,32'h00ffa5ff);
        // Start and fire/direction mapping through the actual CPU I/O path.
        buttons=7'b1100001; repeat(10000) @(negedge clk);
        host(0,32'h41000004,0,0);
        if(result[7:0]!==8'h7f || result[23:16]!==8'hde) $fatal(1,"GG buttons were not mapped: %h",result);
        command(16'h0200,0,0,0,0); repeat(10000) @(negedge clk);
        host(0,32'h41000004,0,0);
        if(result[7:0]!==8'hff || result[23:16]!==8'hff || audio_left!==0 || audio_right!==0)
            $fatal(1,"Focus policy failed: RAM=%h audio=%h/%h",result,audio_left,audio_right);
        buttons=0; command(16'h0200,1,0,0,0);
        check_frames=1;
        while(frames<3) @(negedge clk);
        check_frames=0;
        if(total_red<10000 || total_green<10000) $fatal(1,"Diagnostic image lacks both colors");
        if(audio_left===0 || audio_right!==0) $fatal(1,"Stereo output failed %h/%h",audio_left,audio_right);
        // A save read freezes the real CPU, while SDRAM keeps refreshing.
        command(16'h0302,1,0,0,0); if(result!==32768) $fatal(1,"Save size not returned");
        frozen_cpu=dut.machine.debug_cpu;refresh_before=refreshes;
        for(i=0;i<32768;i=i+4) expect_read(32'h40000000+i,i==0 ? 32'h4433225a : 32'hffffffff);
        if(dut.machine.debug_cpu!==frozen_cpu || refreshes<=refresh_before) $fatal(1,"Save freeze/refresh failed");
        command(16'h0303,1,0,0,0);
        command(16'h0101,0,0,0,0);
        command(16'h0302,1,0,0,0);expect_read(32'h40000000,32'h4433225a);command(16'h0303,1,0,0,0);
        command(16'hffff,0,0,0,1);
        $display("PASS firmware-to-SDRAM-to-real-GG: host lifecycle, byte order, CRC, lengths, inputs, focus, 160x144 frames, stereo, save freeze/export, retained save, refresh");
        $finish;
    end
    initial begin #200000000; $fatal(1,"SoC test timeout"); end
endmodule
