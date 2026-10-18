`timescale 1ns/1ps
module tb_rom_type;
    reg clk=0; always #10 clk=~clk;
    reg reset=1,begin_load=0,finish_load=0,byte_valid=0,hint_write=0;
    reg [23:0] byte_address=0;
    reg [7:0] byte_data=0;
    reg [31:0] hint_value=0,committed_length=0;
    reg [1:0] system_override=0;
    wire hint_rejected,header_conflict;
    wire [1:0] hint_type,header_type,selected_type,selected_source;
    localparam [63:0] SIG=64'h544d522053454741;
    sega_rom_type dut(.*);

    task automatic start_load;
        begin
            @(negedge clk); begin_load=1; committed_length=0;
            @(negedge clk); begin_load=0;
        end
    endtask
    task automatic byte_at(input [23:0] address,input [7:0] value);
        begin
            @(negedge clk); byte_valid=1; byte_address=address; byte_data=value;
            @(negedge clk); byte_valid=0;
        end
    endtask
    task automatic write_header(input [23:0] base,input [3:0] code);
        integer k;
        begin
            for(k=0;k<8;k=k+1) byte_at(base+k,SIG[63-8*k-:8]);
            byte_at(base+15,{code,4'he});
        end
    endtask
    task automatic write_hint(input [31:0] value,input expected_rejection);
        begin
            @(negedge clk); hint_write=1; hint_value=value;
            #1;
            if(hint_rejected!==expected_rejection)
                $fatal(1,"Hint %h rejection=%b expected=%b",value,hint_rejected,expected_rejection);
            @(negedge clk); hint_write=0;
        end
    endtask
    task automatic check(input [1:0] kind,source,header,input conflict);
        begin
            #1;
            if(selected_type!==kind || selected_source!==source ||
               header_type!==header || header_conflict!==conflict)
                $fatal(1,"type/source/header/conflict=%d/%d/%d/%b expected %d/%d/%d/%b",
                    selected_type,selected_source,header_type,header_conflict,
                    kind,source,header,conflict);
        end
    endtask
    initial begin
        repeat(2) @(negedge clk); reset=0;
        start_load();
        write_header(24'h007ff0,4'h6);
        committed_length=32'h00007fff;
        check(0,0,0,0); // Candidate extends beyond committed data.
        committed_length=32'h00008000;
        check(1,3,1,0); // GG export header.
        write_hint(2,1); // Hints may not change after data starts.
        check(1,3,1,0);
        @(negedge clk); finish_load=1;
        @(negedge clk); finish_load=0;
        write_hint(2,1); // Also rejected after FILE_WRITE_END.

        start_load();
        check(0,0,0,0); // New epoch clears old header evidence.
        write_hint(3,1); // Invalid 32-bit value rejected without truncation.
        write_hint(32'h10000001,1);
        write_hint(2,0);
        write_header(24'h007ff0,4'h5);
        committed_length=32'h00008000;
        check(2,2,1,0); // Explicit SMS hint beats a GG header.
        system_override=1;
        check(1,1,1,0); // Manual choice beats both.
        system_override=0;

        start_load();
        write_header(24'h001ff0,4'h3);
        write_header(24'h003ff0,4'h6);
        committed_length=32'h00004000;
        check(0,0,0,1); // Conflicting headers never depend on chunk order.
        system_override=2;
        check(2,1,0,1);
        system_override=0;

        start_load();
        write_header(24'h001ff0,4'h2);
        committed_length=32'h00002000;
        check(0,0,0,0); // Valid signature with unknown region is unresolved.
        $display("PASS ROM type: epoch, hint ordering, header bounds/conflicts, precedence, unknown type");
        $finish;
    end
    initial begin #1000000; $fatal(1,"ROM type test timed out"); end
endmodule
