# GG and SMS Bub v0.1.0-alpha.10 investigation

Alpha.10 is the next core candidate after the alpha.9 device trials. Do not
publish or tag it until a changed package has passed simulation, routed Rev4
timing, and device checks. The October 18 alpha.9 bitstream remains the
comparison baseline.

## Open hardware findings

- [Issue #7](https://github.com/czarroland/gamegear-bub/issues/7): October 27
  Gauntlet photos at 2× and 3× (after a reported 16 R taps) show a thin bright
  top-edge line, but gameplay advanced between shots. Native row-zero presence
  is inconclusive. The original SMS first-row diagnostic in draft PR #12
  passed a real-engine Verilator test on October 27, with row zero red and
  following rows blue. The 32 KiB ROM was copied to
  `roms/MasterSystem/sms-top-row-diagnostic.sms` on the BUB card and read back
  with matching SHA-256. Its controlled Rev4 device check remains.
- [Issue #10](https://github.com/czarroland/gamegear-bub/issues/10): The same
  262,144-byte Alien 3 image, SHA-256
  `01e1a84319d4c3c6462ffd79cc77733cfef62aca07cf6c111b5d3c4ed6a364e7`,
  remains black with no sound after the tester's firmware update. Six copies
  on the mounted BUB card match this hash. A subsequent video of the separate
  1000 KB/s Slow Test core again shows a black screen after this ROM is
  selected. The tester also forced NTSC and retried at both 2× and 3×,
  restarting the core between changes; video stayed black. Simulation
  produces nonblack video. Forcing System to Master System with TV at NTSC
  also stayed black. PAL clock selection, automatic system detection, and
  file-transfer speed alone do not explain the device failure.

## Isolated transfer trial on the BUB card

On October 27, `cores/Sega8bit.SlowTrial` was installed as **GG and SMS Bub
Slow Test** alongside `Sega8bit.NextTrial`. The initial 33-byte menu name
exceeded the firmware's 32-byte core-name limit and was corrected after the
core failed to appear. The Next Trial folder was restored for comparison.
The Slow Test has the *identical*
alpha.9 Rev4 bitstream (SHA-256
`d62f8c53a620f8c232eca25e1b900eb039bff50cc166489153733ea7835262d9`)
and settings. Only both file `max_transfer_speed` limits changed from 5000 to
1000 KB/s. The source package and README are in
`build/alpha10-slow-transfer-trial/` (local ignored build output).

The user confirmed that the slow core appears and runs Gauntlet. Alien 3 still
shows a black screen after selection, so lowering transfer speed did not
resolve issue #10. Auto selects PAL for this exact CRC, but the forced-NTSC
retest also remained black. A forced Master System type check also stayed
black. This trial is **not** an alpha.10 build or release.

## Release gate

Alpha.10 can be tagged `v0.1.0-alpha.10` after a concrete fix, passing core
simulations and Rev4 route, and a device play check of the changed package.
Keep Alien 3 compatibility unclaimed until it shows video and sound on Rev4.
