`timescale 1ns/1ps
// A protocol checker, not a substitute for the fitted SDRAM's vendor model.
module sdram_model(input wire clk,cke,cs,ras,cas,we,
    input wire [1:0] bank,dqm,input wire [12:0] address,
    input wire [15:0] data_out,input wire data_dir,output reg [15:0] data_in=0,
    output integer refreshes=0);
    reg [15:0] ram[0:16777215];
    reg [12:0] row[0:3];
    reg [3:0] open_bank=0;
    integer active_at[0:3];
    integer cycle=0,last_refresh=0,read_delay=0;
    reg [23:0] pending_word;
    reg mode_loaded=0;
    integer word_address;
    always @(posedge clk) begin
        cycle=cycle+1;
        if(read_delay!=0) begin
            if(read_delay==1) data_in<=ram[pending_word];
            read_delay=read_delay-1;
        end
        if(mode_loaded && cycle-last_refresh>420) $fatal(1,"SDRAM refresh deadline missed");
        if(cke && !cs) case({ras,cas,we})
            3'b011: begin
                if(open_bank[bank]) $fatal(1,"ACTIVE without precharge");
                row[bank]=address; open_bank[bank]=1; active_at[bank]=cycle;
            end
            3'b101,3'b100: begin
                if(!mode_loaded || !open_bank[bank]) $fatal(1,"Column command without active row/mode");
                if(cycle-active_at[bank]<2) $fatal(1,"tRCD violated");
                if(!address[10]) $fatal(1,"Expected auto-precharge");
                word_address={bank,row[bank],address[8:0]};
                if(!we) begin
                    if(!data_dir) $fatal(1,"WRITE without data direction");
                    if(!dqm[0]) ram[word_address][7:0]=data_out[7:0];
                    if(!dqm[1]) ram[word_address][15:8]=data_out[15:8];
                end else begin
                    if(data_dir || dqm!=0) $fatal(1,"Masked/driven READ");
                    pending_word=word_address; read_delay=2;
                end
                open_bank[bank]=0;
            end
            3'b010: if(address[10]) open_bank=0; else open_bank[bank]=0;
            3'b001: begin
                if(open_bank!=0) $fatal(1,"REFRESH with an open bank");
                refreshes=refreshes+1; last_refresh=cycle;
            end
            3'b000: begin
                if(bank!=0 || address!=13'h220 || refreshes<8) $fatal(1,"Invalid SDRAM initialization/mode");
                mode_loaded=1; last_refresh=cycle;
            end
            default: ;
        endcase
    end
endmodule
