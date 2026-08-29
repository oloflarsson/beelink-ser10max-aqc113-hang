# Beelink SER10 MAX: the AQC113 2.5 GbE NIC hangs on a CPU boost ramp

An executable bug report. The on-board Marvell AQtion AQC113 on a Beelink
SER10 MAX (Ryzen AI 9 HX 470, BIOS V102) hangs — link gone, firmware dead —
on the **rising edge of a CPU boost from idle**. Reproduced 11 times in one
day on demand; prevented by lowering the boost ceiling by 0.8 GHz.

- **Symptom:** `atlantic … link change old 2500 new 0`; the link never comes
  back by itself. Port LED off on some reports.
- **Fingerprint:** the NIC's MMIO reads all-ones (`ethtool -S` returns
  `0xFFFFFFFF…`, PHY temperature `-1`), the PCI config space blinks to `ffff`
  for under two seconds and returns, the root-port link stays trained at
  16 GT/s, and the driver's re-init reports **`atlantic: Boot code hanged`**
  with a `WARNING … aq_a2_fw_deinit` splat. The chip resets itself; the
  hardware PCIe block comes back, the firmware does not.
- **Trigger:** idle box → a burst of CPU work that ramps the package from
  ~4.5 W to 45–50 W in 6–9 s, while the NIC is receiving *anything* (an idle
  ssh session is enough). Not heat: PHY 38–44 °C every time. Not sustained
  power: 20 min at the PPT is clean. Not DMA: 144 GB of RX is clean.
- **Recovery:** link bounce and `ethtool -r` fail; **PCI remove + rescan
  recovers it every time** (10 of 10, 45–53 s, no power cycle).
- **Workaround:** cap the CPU at 4.5 GHz (`cpupower frequency-set -u 4.5GHz`).
  Bracketed: 2.0, 3.0, 4.0 and 4.5 GHz each clean for 15 min under the
  reproducer; an uncapped control between them dropped in 16 s. The last
  0.8 GHz of single-core boost is a ~20 W voltage knee (bursts peak 28 W
  capped vs 47–50 W uncapped). Cost: nothing — all-core is PPT-limited to
  ~3.8 GHz anyway.

Full evidence and the hypothesis table: [FINDINGS.md](FINDINGS.md).
Raw logs: [evidence/](evidence/). What did *not* reproduce it, with scripts:
[not-reproducing/](not-reproducing/).

## Reproduce it

Two machines on the same wired LAN: the **box** (SER10 MAX) and a **client**
(anything with `ssh` and `curl`). Requests must arrive over the wire; the
same bursts generated locally on the box reproduce only 1 time in 4.

The load is a public CPU text-to-speech container (PyTorch). It is the only
load found that triggers the fault; see FINDINGS for what was tried instead.

```sh
# box (needs docker or podman, ethtool, pciutils; run as root)
reproduce/box/run-kokoro.sh          # starts the container on 127.0.0.1:8880, --cpus 8
reproduce/box/monitor.sh &           # 2 s samples to ./monitor.log (power, clocks, temps, NIC state)

# client
BOX=<box LAN address> reproduce/client/bursts.sh   # random 1–12 s idle, then 8 parallel requests, for 25 min
```

Expected: within 16 s to 4.5 min, `monitor.log` shows `carrier=0`, `phy=-1C`,
and the kernel logs `link change old 2500 new 0`. Typically the sample just
before shows `vid=ffff` (config space unreadable) with carrier still 1.

```sh
# box: bring it back without a reboot
reproduce/box/recover.sh             # ip link bounce → ethtool -r → PCI remove + rescan
```

## Work around it

```sh
workaround/cap-boost.sh              # scaling_max_freq = 4.5 GHz on every CPU (until reboot)
```

NixOS: `powerManagement.cpufreq.max = 4500000;` — [workaround/nixos.nix](workaround/nixos.nix).
A flake is included for the Nix-inclined: `nix run .#monitor`, `nix run .#bursts`,
`nix run .#avxburn`.

## Versions

| | |
|---|---|
| Machine | Beelink SER10 MAX, AMD Ryzen AI 9 HX 470 (Zen 5, 24 threads) |
| BIOS | `GPT.4xx.SERM1.V102.P8C0M0C15.09.BL` (2026-01-20), latest at time of writing |
| NIC | Marvell AQtion AQC113 `1d6a:04c0` rev 03, firmware 1.5.45 (`ATL2FW 105002d`), PCIe 16 GT/s ×1 (downgraded from ×4) behind root port `00:02.4` |
| OS | NixOS 26.05, kernels 7.1.7 and 7.2.1 (in-tree `atlantic`), both reproduce |
| Also reported on | Windows, by another SER10 MAX owner (Beelink forum thread 12040) |

Related: Beelink forum thread 12040, [Aquantia/AQtion#74](https://github.com/Aquantia/AQtion/issues/74).

## Status

Open. Nothing in this repository fixes the fault; the cap prevents it and the
rescan recovers it. What is still unknown is *why* a PyTorch inference ramp
triggers it when steady AVX-512, load transients, memory-bandwidth bursts and
GEMM bursts of the same power do not — see "Open" in FINDINGS.
