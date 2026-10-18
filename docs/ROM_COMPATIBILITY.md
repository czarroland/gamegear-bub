# ROM hacks and Brazilian Master System compatibility

This is a source audit, not a compatibility list. The pinned upstream is
[MiSTer SMS/GG `8443a0d`](https://github.com/MiSTer-devel/SMS_MiSTer/tree/8443a0d19a88aff7a5900011bccf386daf146945).
The current public alpha.6 package still has a 4 MiB loader limit. The
development source now accepts an ordered upload of up to 16 MiB and tests its
last word through the SoC and SDRAM model; no 16 MiB game has been booted on
Gamebub. A separate local PAL test package is installed on the BUB card, but
no GitHub release has been published from this change.

| Software/path | MiSTer behavior at the pin | Gamebub development state |
| --- | --- | --- |
| Ordinary `.sms` and `.gg` hacks | Same engine, with Sega/Codemasters and several other mapper detectors; a hack may change its header or mapper evidence | GG/SMS NTSC engine present. Current firmware supplies no extension hint; use a forced System setting for headerless or mislabeled games. Each modified ROM needs its own gameplay test |
| SMS-mode Game Gear games | [Upstream README](https://github.com/MiSTer-devel/SMS_MiSTer/blob/8443a0d19a88aff7a5900011bccf386daf146945/README.md) advises `.sms` for `.gg` dumps that actually run as SMS | Force System to Master System under the current firmware; changing only the extension does not select SMS on alpha.6 |
| Nonstandard mapper hacks | [Mapper detector](https://github.com/MiSTer-devel/SMS_MiSTer/blob/8443a0d19a88aff7a5900011bccf386daf146945/rtl/mapper_detect.vhd) includes static signatures, CRCs and runtime write heuristics for Codemasters, Dahjee, linear/locked Sega, Zemina/Nemesis, Wonder Kid, Castle, Janggun, EEPROM and other cases | These upstream modules are staged, but only Auto and Sega have limited Gamebub tests. A patch can invalidate CRC-based identification. The menu offers manual Sega/Codemasters/Dahjee/Linear/Zemina, not every detected mapper |
| TecToy Master System Evolution/Noza 132-game flash | [MiSTer README](https://github.com/MiSTer-devel/SMS_MiSTer/blob/8443a0d19a88aff7a5900011bccf386daf146945/README.md) specifies a complete 16 MiB `.sms` flash and identifies two exact revisions by full-image CRC-32, `0C90A6CA` and `CBD7FF82`. Its mapper, I/O, clone VDP and per-game GG behavior form one profile | Upload capacity is now 16 MiB in source, with a high-address transport test. The Evolution profile, 132-game launcher, PAL behavior, controls and saves are **unverified** on Gamebub. Extracted individual games or modified flash images do not automatically get the exact-CRC profile |

The loader still requires a four-byte-aligned ROM of at least 32 KiB. Smaller
homebrew images and ROMs with a 512-byte copier prefix need separate length and
normalization work. The loader does not alter ROM bytes or filenames. A 16 MiB
boundary test skips the synthetic image's middle; it cannot establish full
upload duration, CRC recognition, mapper banking, video or playability. The
first complete Evolution test needs a user-owned exact flash image and its
SHA-256 recorded locally; commercial images must not be committed or bundled.

PAL and FM are independent compatibility axes. A Brazil or Europe filename
does not establish PAL timing, and enabling FM does not turn PSG-only music into
FM. The separate PAL trial passed rev4 timing and several PAL ROMs played on
the device, but their filenames and hashes were not recorded. The combined
PAL and control-fix build needs its own device check. FM synthesis is still
absent from the shared SoC. Test each title with its actual region, mapper,
System and TV settings.
