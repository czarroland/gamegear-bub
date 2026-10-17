# FM implementation gate

Status: research checkpoint, 2026-10-16. The public `v0.1.0-alpha.5` core has
PSG audio only. No FM source or FM-enabled bitstream is included in this repo or
its releases.

The target remains one Game Gear / Master System bitstream with YM2413 FM,
normal PSG mixing, and a selectable SMS FM setting. FM register writes and
`$F2` detection/mute behavior must match the pinned MiSTer source before the
Gamebub audio adapter is evaluated. The hardware report for alpha.5 does not
cover FM.

## Source routes examined

| Route | Evidence | Current decision |
| --- | --- | --- |
| [Pinned MiSTer VM2413](https://github.com/MiSTer-devel/SMS_MiSTer/tree/8443a0d19a88aff7a5900011bccf386daf146945/rtl/VM2413) | `OPLL.qip` lists 19 VHDL sources. `opll.vhd` carries a noncommercial restriction requiring prior written permission for sale or commercial use. | Use only as a local reference until redistribution permission or a qualified compatibility determination covers source and combined bitstream. Preserve its notices. |
| [IKAOPLL](https://github.com/ika-musume/IKAOPLL/tree/15b373be57b52b4e3eb9b99653dabc5095f7a644) | Repository declares BSD-2-Clause, but its README says the 9-bit output design and VRC7 patch were copied from [Nuked-SMS-FPGA](https://github.com/nukeykt/Nuked-SMS-FPGA), whose repository declares GPL-2.0. Its sound output and timing differ from MiSTer's VM2413 until measured. | Technical candidate only. Check provenance/obligations and run a native register-stream comparison before selecting it. |
| [JTOPL YM2413](https://github.com/jotego/jtopl) | Repository declares GPL-3.0; its feature table marks `jt2413` work in progress. | Not a ready drop-in FM implementation. |

The [pinned Gamebub framework license](https://github.com/gamebub/framework/blob/db9d3b0e7989db4a8edc66e47b843097d71f078c/LICENSE)
grants its weakly reciprocal option only for unmodified framework use. This
build applies `patches/framework-video-runtime.patch`. Its combined-work
obligations therefore also need a qualified review. These observations do not
constitute a legal determination.

## Private technical checks

- The exact IKAOPLL commit above was fetched into ignored `build/ikaopll`.
  Verilator 5.020 linted its top and eight supporting Verilog files without a
  fatal error. Width warnings remain; this is not a parity or synthesis pass.
- The pinned MiSTer VM2413 sources remain only in ignored
  `build/upstream-sms`. A local GHDL 4.1 analysis with VHDL-93,
  `-fsynopsys -fexplicit -C`, and package-first order reached
  `controller.vhd` and stopped on `ch_type'range` and incomplete case choices.
  Identifier and syntax portability work is still needed for an independent
  private oracle. No modified copy has been added to source control.

## Release gate and next implementation steps

1. Resolve the selected FM source's redistribution terms and the patched
   framework's combined-work obligations before any public FM source,
   bitstream, or prerelease. A private experiment does not clear this gate.
2. Build a deterministic native FM reference trace from the pinned MiSTer
   implementation: bus writes, instruments, rhythm, `$F2`, region, FM toggle,
   and GG→SMS→GG resets. Pin input bytes and clock alignment.
3. Integrate one licensed FM engine into the shared machine, preserve the
   native bus and mixer policy, and compare PCM against the reference. Measure
   the Gamebub audio adapter separately.
4. Route the combined core, close timing, then publish a new immutable
   prerelease and install the identical ZIP on the BUB card for hardware tests.
