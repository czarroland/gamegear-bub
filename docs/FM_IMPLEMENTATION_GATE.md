# FM implementation gate

Status: research checkpoint, 2026-10-16. The public `v0.1.0-alpha.6` core has
PSG audio only. No FM source or FM-enabled bitstream is included in this repo or
its releases.

The target remains one Game Gear / Master System bitstream with YM2413 FM,
normal PSG mixing, and a selectable SMS FM setting. FM register writes and
`$F2` detection/mute behavior must match the pinned MiSTer source before the
Gamebub audio adapter is evaluated. The hardware report for alpha.5/alpha.6 does not
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
  `build/upstream-sms`. The original test stimulus and
  `scripts/run_fm_oracle.py` are tracked; the restricted upstream files and
  their disposable GHDL-compatible copies remain ignored. The runner verifies
  all 19 source hashes and `OPLL.qip` against
  `manifests/fm_oracle_sources.json`, then compiles them in dependency order
  under GHDL 4.1 with `-fsynopsys -fexplicit -C`. From the repository root,
  run `python3 scripts/run_fm_oracle.py` when GHDL is installed, or use the
  existing local test container with
  `docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work gamegear-test:latest python3 scripts/run_fm_oracle.py`.
  A private register-write simulation produced
  125 nonconstant samples from one keyed tone (`$30=$10`, `$10=$AA`,
  `$20=$15`) after the writes were held across complete chip frames. The
  unsigned `mixout` samples span 0–511; the local CSV SHA-256 is
  `5f930230e6a62c83708ec97ab97d7a39e77175d16a9cab346fda8df6d7513f6b`.
  The runner reproduced that exact hash on 2026-10-16. Startup unknown-value
  warnings end by 385 ns. This is one smoke trace, not a validated parity
  oracle or an FM-enabled Gamebub build.
- The same pinned OPLL now produces a second deterministic CSV from original
  stimuli in `tests/tb_fm_vectors.vhdl`: all 15 preset instruments with key
  on/off, a user instrument assigned to all nine melodic channels, selective
  key release and reset, plus rhythm entry, simultaneous percussion, partial
  release and exit. Each register pair is separated by two complete 72-enable
  OPLL frames. The CSV records both the raw unsigned 14-bit value and its
  signed interpretation. GHDL 4.1 produced 1,520 samples with SHA-256
  `5636351bd79a3d803214d8ded633a375d050a770ae9807c0e752bffff93155c1`.
  This tests the OPLL component directly. It does not cover the shared Sega
  system's `$F0`/`$F1` decode, `$F2` control/readback, PSG mixing, region
  policy, Gamebub resampling, or DAC/HDMI delivery.
- The Gamebub 48 kHz adapter now divides each signed accumulation by its
  actual 1,118- or 1,119-clock window length. An independent sample-by-sample
  test model passed 107 varying windows, and the signed-audio regression
  passed. This corrects a small PSG gain error and prepares the shared adapter
  for FM; it does not validate FM synthesis or the DAC/HDMI transport.

## Release gate and next implementation steps

1. Resolve the selected FM source's redistribution terms and the patched
   framework's combined-work obligations before any public FM source,
   bitstream, or prerelease. A private experiment does not clear this gate.
2. Extend the deterministic reference beyond the direct OPLL vectors into
   the pinned MiSTer system: `$F0`/`$F1` bus writes, `$F2` detection and
   mixing, region, live FM toggle, and GG→SMS→GG resets. Pin input bytes and
   clock alignment.
3. Integrate one licensed FM engine into the shared machine, preserve the
   native bus and mixer policy, and compare PCM against the reference. Measure
   the Gamebub audio adapter separately.
4. Route the combined core, close timing, then publish a new immutable
   prerelease and install the identical ZIP on the BUB card for hardware tests.
