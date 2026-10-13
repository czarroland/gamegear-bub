// SPDX-License-Identifier: GPL-3.0-or-later
module gamegear_soc #(parameter integer CLOCK_HZ=53691275)(
    input wire clk,reset,input wire [6:0] buttons,
    input wire mem_enable,mem_write,input wire [31:0] mem_address,mem_data_write,
    output wire mem_done,output reg [31:0] mem_data_read,
    input wire command_request,output wire command_busy,command_done,command_error,
    input wire memory_initialized,memory_ready,memory_done,input wire [7:0] memory_data_read,
    output wire memory_request,memory_write,output wire [24:0] memory_address,
    output wire [7:0] memory_data_write,
    output wire [3:0] red,green,blue,output wire data_enable,hblank,vblank,
    output wire signed [15:0] audio_left,audio_right);
    localparam M_IDLE=0,M_REG=1,M_ROM_REQUEST=2,M_ROM_WAIT=3,
               M_SAVE_WRITE=4,M_SAVE_ADDRESS=5,M_SAVE_WAIT=6,M_SAVE_CAPTURE=7,
               M_FINISH=8,M_DONE=9,M_WRAM_ADDRESS=10,M_WRAM_WAIT=11,M_WRAM_CAPTURE=12;
    localparam C_IDLE=0,C_BUSY=1,C_DONE=2,C_ERROR=3;
    reg [3:0] mem_state=0;
    reg [1:0] command_state=0;
    reg [31:0] host_address,host_word,read_word;
    reg host_write;
    reg [1:0] byte_index;
    reg [31:0] host_regs[0:3];
    reg setup_complete=0,run=0,focus=0,rom_loading=0,save_loading=0,save_reading=0,rom_ready=0;
    reg region=0;
    reg [3:0] mapper=0;
    reg [31:0] rom_length=0,rom_committed=0,save_committed=0;
    reg [23:0] rom_mask=0;
    reg [31:0] crc_state=32'hffffffff,last_error=0,stalls=0;
    reg [5:0] reset_count=0;
    reg clear_wram=0;
    reg save_clear=0;
    reg [14:0] save_clear_address=0;
    reg [2:0] command_delay=0;
    reg inflight=0,owner_host=0;
    reg [23:0] inflight_address,cached_address;
    reg [7:0] cpu_rom_data=8'hff;
    reg cpu_rom_valid=0;
    wire ce_cpu,ce_vdp,ce_pix,ce_sp;
    wire rom_read;
    wire [23:0] rom_address;
    wire [23:0] masked_address=rom_address & rom_mask;
    wire freeze=save_loading || save_reading;
    wire machine_reset_n=!reset && run && rom_ready && reset_count==0;
    wire wram_busy;
    wire machine_running=machine_reset_n && !wram_busy;
    wire [6:0] effective_buttons=focus ? buttons : 7'd0;
    wire [11:0] native_color;
    wire native_hblank,native_vblank;
    wire signed [15:0] raw_left,raw_right;
    wire [7:0] save_q,wram_q;
    wire [14:0] save_address=save_clear ? save_clear_address : host_address[14:0]+{13'd0,byte_index};
    wire save_we=save_clear || mem_state==M_SAVE_WRITE;
    wire [7:0] save_data=save_clear ? 8'hff : host_word[byte_index*8+:8];
    wire [12:0] wram_address=host_address[12:0]+{11'd0,byte_index};
    wire cpu_needs_byte=machine_running && !freeze && rom_read &&
        (!cpu_rom_valid || cached_address!=masked_address);
    wire host_grant=mem_state==M_ROM_REQUEST;
    wire cpu_grant=cpu_needs_byte && {8'd0,masked_address}<rom_length && !rom_loading;
    assign memory_request=!reset && !inflight && (host_grant || cpu_grant);
    assign memory_write=host_grant;
    assign memory_address=host_grant ? {3'd0,host_address[21:0]+{20'd0,byte_index}} : {1'b0,masked_address};
    assign memory_data_write=host_word[byte_index*8+:8];
    wire rom_wait_n=!rom_read || !machine_running ||
        (cpu_rom_valid && cached_address==masked_address);
    assign mem_done=mem_state==M_DONE && !reset;
    assign command_busy=command_state==C_BUSY;
    assign command_done=command_state==C_DONE || command_state==C_ERROR;
    assign command_error=command_state==C_ERROR;
    function automatic [31:0] crc_byte(input [31:0] crc,input [7:0] value);
        reg [31:0] c; integer bit_index;
        begin
            c=crc ^ {24'd0,value};
            for(bit_index=0;bit_index<8;bit_index=bit_index+1)
                c=c[0] ? (c>>1)^32'hedb88320 : c>>1;
            crc_byte=c;
        end
    endfunction
    function automatic [23:0] size_mask(input [31:0] size);
        reg [23:0] bits;
        begin
            // The caller accepts only 32 KiB..4 MiB. Spread the highest set
            // bit of size-1 to form next_power_of_two(size)-1. This is a short
            // prefix network rather than 22 serial comparisons and muxes.
            bits=size[23:0]-24'd1;
            bits=bits | (bits>>1);
            bits=bits | (bits>>2);
            bits=bits | (bits>>4);
            bits=bits | (bits>>8);
            bits=bits | (bits>>16);
            size_mask=bits;
        end
    endfunction
    gg_enables enables(clk,reset,ce_cpu,ce_vdp,ce_pix,ce_sp);
    gamegear_machine machine(.clk(clk),.reset_n(machine_reset_n),.clear_wram(clear_wram),.freeze(freeze),
        .ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp),.rom_wait_n(rom_wait_n),
        .buttons(effective_buttons),.region(region),.mapper(mapper),
        .load_we(inflight && owner_host && memory_done),.load_address(inflight_address),
        .load_data(host_word[byte_index*8+:8]),.rom_read(rom_read),.rom_address(rom_address),.rom_data(cpu_rom_data),
        .color(native_color),.hblank(native_hblank),.vblank(native_vblank),.audio_left(raw_left),.audio_right(raw_right),
        .save_host_address(save_address),.save_host_data(save_data),.save_host_we(save_we),.save_host_q(save_q),
        .debug_wram_address(wram_address),.debug_wram_q(wram_q),.wram_busy(wram_busy),
        .debug_cpu(),.debug_vdp(),.debug_cram(),.debug_io(),.debug_mapper());
    gg_video video(.clk(clk),.reset(reset),.run(machine_running),.freeze(freeze),.ce_pix(ce_pix),
        .color(native_color),.native_hblank(native_hblank),.native_vblank(native_vblank),
        .red(red),.green(green),.blue(blue),.data_enable(data_enable),.hblank(hblank),.vblank(vblank));
    gg_audio #(.CLOCK_HZ(CLOCK_HZ)) audio(.clk(clk),.reset(reset),
        .mute(!machine_running || !focus || freeze),.raw_left(raw_left),.raw_right(raw_right),
        .left(audio_left),.right(audio_right),.sample_tick());
    integer j;
    always @(posedge clk) begin
        clear_wram<=0;
        if(reset) begin
            mem_state<=M_IDLE; command_state<=C_IDLE; mem_data_read<=0;
            setup_complete<=0; run<=0; focus<=0; rom_loading<=0;
            save_loading<=0; save_reading<=0; rom_ready<=0;
            region<=0; mapper<=0; rom_length<=0; rom_mask<=0; rom_committed<=0; save_committed<=0;
            crc_state<=32'hffffffff; last_error<=0; stalls<=0; reset_count<=0;
            save_clear<=0; save_clear_address<=0; command_delay<=0;
            inflight<=0; cpu_rom_valid<=0; cpu_rom_data<=8'hff; cached_address<=0;
            byte_index<=0; host_address<=0; host_word<=0; read_word<=0; host_write<=0;
            for(j=0;j<4;j=j+1) host_regs[j]<=0;
        end else begin
            if(reset_count!=0) reset_count<=reset_count-1'b1;
            if(!machine_running || !rom_read) cpu_rom_valid<=0;
            if(cpu_needs_byte && {8'd0,masked_address}>=rom_length) begin
                cpu_rom_valid<=1; cpu_rom_data<=8'hff; cached_address<=masked_address;
            end
            if(machine_running && ce_cpu && !rom_wait_n) stalls<=stalls+1'b1;
            if(memory_request && memory_ready) begin
                inflight<=1; owner_host<=host_grant; inflight_address<=memory_address[23:0];
                if(host_grant) mem_state<=M_ROM_WAIT;
            end
            if(memory_done && inflight) begin
                inflight<=0;
                if(owner_host) begin
                    rom_committed<=rom_committed+1'b1;
                    crc_state<=crc_byte(crc_state,host_word[byte_index*8+:8]);
                    if(byte_index==3) mem_state<=M_FINISH;
                    else begin byte_index<=byte_index+1'b1; mem_state<=M_ROM_REQUEST; end
                end else begin
                    cpu_rom_data<=memory_data_read; cached_address<=inflight_address; cpu_rom_valid<=1;
                end
            end
            if(save_clear) begin
                if(save_clear_address==32767) begin save_clear<=0; command_delay<=3; end
                else save_clear_address<=save_clear_address+1'b1;
            end
            case(mem_state)
                M_IDLE: if(mem_enable) begin
                    host_address<=mem_address; host_word<=mem_data_write; host_write<=mem_write;
                    byte_index<=0; read_word<=0;
                    if(mem_address[1:0]!=0) begin last_error<=2; mem_state<=M_FINISH; end
                    else if(mem_address>=32'h30000000 && mem_address<32'h30400000) begin
                        if(!mem_write || !rom_loading) begin last_error<=3; mem_state<=M_FINISH; end
                        else if(mem_address-32'h30000000!=rom_committed) begin last_error<=4; mem_state<=M_FINISH; end
                        else mem_state<=M_ROM_REQUEST;
                    end else if(mem_address>=32'h40000000 && mem_address<32'h40008000) begin
                        if(mem_write && save_loading && !save_clear && mem_address-32'h40000000==save_committed)
                            mem_state<=M_SAVE_WRITE;
                        else if(!mem_write && save_reading) mem_state<=M_SAVE_ADDRESS;
                        else begin last_error<=3; mem_state<=M_FINISH; end
                    end else if(mem_address>=32'h41000000 && mem_address<32'h41002000 && !mem_write)
                        mem_state<=M_WRAM_ADDRESS;
                    else mem_state<=M_REG;
                end
                M_REG: begin
                    mem_state<=M_FINISH;
                    if(host_address>=32'hf0000000 && host_address<=32'hf000000c) begin
                        if(host_write) host_regs[host_address[3:2]]<=host_word;
                        else read_word<=host_regs[host_address[3:2]];
                    end else if(host_write) begin
                        case(host_address)
                            32'h10: if(region!=host_word[0]) begin
                                region<=host_word[0]; reset_count<=32; clear_wram<=1;
                            end
                            32'h14: if(host_word<=5 && mapper!=host_word[3:0]) begin
                                mapper<=host_word[3:0]; reset_count<=32; clear_wram<=1;
                            end
                            32'h20: if(host_word[0]) begin reset_count<=32; clear_wram<=1; end
                            default: last_error<=1;
                        endcase
                    end else begin
                        case(host_address)
                            32'h0: read_word<=32'h47474231; // GGB1 ABI
                            32'h4: read_word<=32'h00010000;
                            32'h8: read_word<=32'h0000000f; // GG, stereo, save, diagnostics
                            32'hc: read_word<=1; // GG profile
                            32'h10: read_word<={31'd0,region};
                            32'h14: read_word<={28'd0,mapper};
                            32'h18: read_word<=32'h00a00090; // 160 x 144
                            32'h100: read_word<=rom_length;
                            32'h104: read_word<=rom_committed;
                            32'h108: read_word<=crc_state^32'hffffffff;
                            32'h10c: read_word<={24'd0,memory_initialized,save_reading,save_loading,rom_loading,focus,setup_complete,run,rom_ready};
                            32'h110: read_word<=last_error;
                            32'h114: read_word<=stalls;
                            default: begin read_word<=0; last_error<=1; end
                        endcase
                    end
                end
                M_SAVE_WRITE: begin
                    save_committed<=save_committed+1'b1;
                    if(byte_index==3) mem_state<=M_FINISH;
                    else byte_index<=byte_index+1'b1;
                end
                M_SAVE_ADDRESS: mem_state<=M_SAVE_WAIT;
                M_SAVE_WAIT: mem_state<=M_SAVE_CAPTURE;
                M_SAVE_CAPTURE: begin
                    read_word[byte_index*8+:8]<=save_q;
                    if(byte_index==3) mem_state<=M_FINISH;
                    else begin byte_index<=byte_index+1'b1; mem_state<=M_SAVE_ADDRESS; end
                end
                M_WRAM_ADDRESS: mem_state<=M_WRAM_WAIT;
                M_WRAM_WAIT: mem_state<=M_WRAM_CAPTURE;
                M_WRAM_CAPTURE: begin
                    read_word[byte_index*8+:8]<=wram_q;
                    if(byte_index==3) mem_state<=M_FINISH;
                    else begin byte_index<=byte_index+1'b1; mem_state<=M_WRAM_ADDRESS; end
                end
                M_FINISH: begin mem_data_read<=read_word; mem_state<=M_DONE; end
                M_DONE: mem_state<=M_IDLE;
                default: ;
            endcase
            if(!command_request && command_state!=C_BUSY) command_state<=C_IDLE;
            else if(command_request && command_state==C_IDLE) begin
                command_state<=C_DONE; host_regs[0]<=0;
                case(host_regs[0][15:0])
                    16'h0000: host_regs[0]<=!memory_initialized ? 1 : !setup_complete ? 2 : run ? 4 : 3;
                    16'h0100: if(rom_ready && setup_complete && memory_initialized && !rom_loading && !save_loading && !save_reading)
                        run<=1; else begin command_state<=C_ERROR; last_error<=5; end
                    16'h0101: begin run<=0; cpu_rom_valid<=0; end
                    16'h0102: setup_complete<=1;
                    16'h0200: focus<=host_regs[1][0];
                    16'h0300: if(host_regs[1]==0 && !inflight && mem_state==M_IDLE) begin
                        run<=0; rom_ready<=0; rom_loading<=1; rom_committed<=0;
                        rom_length<=0; crc_state<=32'hffffffff; last_error<=0; stalls<=0;
                        cpu_rom_valid<=0; clear_wram<=1;
                    end else if(host_regs[1]==1 && mem_state==M_IDLE && !save_reading) begin
                        save_loading<=1; save_committed<=0; save_clear<=1; save_clear_address<=0;
                        command_state<=C_BUSY;
                    end else begin command_state<=C_ERROR; last_error<=6; end
                    16'h0301: if(host_regs[1]==0 && rom_loading && mem_state==M_IDLE && !inflight &&
                        host_regs[2]==rom_committed && rom_committed>=32768 && rom_committed<=4194304 &&
                        host_regs[2][1:0]==0 && host_regs[3]==0 && last_error==0) begin
                        rom_length<=rom_committed; rom_mask<=size_mask(rom_committed);
                        rom_loading<=0; rom_ready<=1;
                    end else if(host_regs[1]==1 && save_loading && mem_state==M_IDLE &&
                        host_regs[2]==save_committed && save_committed<=32768 && host_regs[3]==0) save_loading<=0;
                    else begin command_state<=C_ERROR; last_error<=5; end
                    16'h0302: if(host_regs[1]==1 && !save_loading && !save_reading) begin
                        save_reading<=1; host_regs[0]<=32768; command_delay<=4; command_state<=C_BUSY;
                    end else begin command_state<=C_ERROR; last_error<=6; end
                    16'h0303: if(host_regs[1]==1 && save_reading) save_reading<=0;
                        else begin command_state<=C_ERROR; last_error<=6; end
                    default: begin command_state<=C_ERROR; last_error<=6; end
                endcase
            end else if(command_state==C_BUSY && !save_clear) begin
                if(command_delay==0) command_state<=C_DONE;
                else command_delay<=command_delay-1'b1;
            end
        end
    end
endmodule
