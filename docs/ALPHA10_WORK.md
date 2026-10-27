# GG and SMS Bub v0.1.0-alpha.10 investigation

Alpha.10 is the next core candidate after the alpha.9 device trials. Do not
publish or tag it until a changed package has passed simulation, routed Rev4
timing, and device checks. The October 18 alpha.9 bitstream remains the
comparison baseline.

## Open hardware findings

- [Issue #7](https://github.com/czarroland/gamegear-bub/issues/7): October 27
  Gauntlet photos at 2× and 3× (after a reported 16 R taps) show a thin bright
  top-edge line, but gameplay advanced between shots. Native row-zero presence
  is inconclusive. The original SMS first-row diagnostic in draft PR #12 still
  needs engine simulation before a controlled device check.
- [Issue #10](https://github.com/czarroland/gamegear-bub/issues/10): The same
  262,144-byte Alien 3 image, SHA-256
  `01e1a84319d4c3c6462ffd79cc77733cfef62aca07cf6c111b5d3c4ed6a364e7`,
  remains black with no sound after the tester's firmware update. Six copies
  on the mounted BUB card match this hash. Simulation produces nonblack video,
  so hardware transfer and runtime behavior need separate checks.

## Isolated transfer trial on the BUB card

On October 27, `cores/Sega8bit.SlowTrial` was installed as **GG and SMS Bub
Slow Transfer Test** alongside `Sega8bit.NextTrial`. It has the *identical*
alpha.9 Rev4 bitstream (SHA-256
`d62f8c53a620f8c232eca25e1b900eb039bff50cc166489153733ea7835262d9`)
and settings. Only both file `max_transfer_speed` limits changed from 5000 to
1000 KB/s. The source package and README are in
`build/alpha10-slow-transfer-trial/` (local ignored build output).

Launch the same Alien 3 ROM with `Sega8bit.SlowTrial` and note whether it
loads video and audio, stays black, or triggers a firmware error. Compare
against `Sega8bit.NextTrial` on the same firmware. A successful slow trial
would point toward transfer handling; a repeated black screen would direct
alpha.10 work toward runtime hardware differences. This trial is **not** an
alpha.10 build or release.

## Release gate

Alpha.10 can be tagged `v0.1.0-alpha.10` after a concrete fix, passing core
simulations and Rev4 route, and a device play check of the changed package.
Keep Alien 3 compatibility unclaimed until it shows video and sound on Rev4.
