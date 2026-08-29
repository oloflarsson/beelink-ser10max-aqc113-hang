# Findings

Everything here was measured on one SER10 MAX over 2026-08-18 → 2026-08-29,
with a 2-second sampler ([reproduce/box/monitor.sh](reproduce/box/monitor.sh))
running throughout: package power (RAPL), mean clock, CPU/PHY/MAC/NVMe
temperatures, and for the NIC: carrier, speed, operstate, a ping bound to the
interface, the root-port `LnkSta` and the device's vendor-ID register read via
`setpci` (config space), and the kernel's running count of link drops.

## 1. The failure mode

Eleven drops on 2026-08-29 (plus two on 2026-08-18 before the sampler
existed), every one identical:

1. Package power ramps from ~4.5 W idle to 45–50 W in 6–9 s. Mean clock across
   24 threads 2.0–3.6 GHz — a *mixed* state, some cores idle, some boosting.
2. Within that ramp, one 2 s sample reads the NIC's vendor ID as **`ffff`**
   (config space not answering) while carrier is still 1 and the ping still
   passes. [evidence/monitor-config-space-blink.log](evidence/monitor-config-space-blink.log)
3. Next sample: config space answers again (`1d6a`), but carrier is 0, the
   PHY/MAC temperature reads `-1` and every `ethtool -S` counter that comes
   from MMIO is all-ones. The root-port `LnkSta` is unchanged: 16 GT/s ×1,
   trained. [evidence/monitor-drop.log](evidence/monitor-drop.log)
4. Kernel: `atlantic … link change old 2500 new 0`, then on any attempt to
   re-init: `atlantic: Boot code hanged` and `WARNING … at aq_a2_fw_deinit`.
   [evidence/dmesg-drop.txt](evidence/dmesg-drop.txt)
5. PHY temperature at the moment of the drop: 38–44 °C, every time.

Reading: the AQC113 resets itself — its PCIe block drops off the bus for less
than a sample and re-enumerates, but the on-chip firmware does not come back.
That is the fingerprint of a supply glitch causing an internal reset, not a
link-training, DMA or thermal problem.

## 2. Recovery

| Step | Result |
|---|---|
| `ip link set down/up` | fails (`RTNETLINK answers: Connection timed out`, second `Boot code hanged`) |
| `ethtool -r` | fails |
| `echo 1 > /sys/bus/pci/devices/0000:c3:00.0/remove; echo 1 > /sys/bus/pci/rescan` | **recovers, 10 of 10**, link back in 45–53 s |

[evidence/watchdog-recovery.txt](evidence/watchdog-recovery.txt) is one full
escalation. That a bus-level remove/rescan works where the driver's own reset
does not says the fault is in the chip's reset domain, not the PHY or cable.

## 3. The trigger

The only load that reproduces it is a burst of parallel requests to a CPU
PyTorch inference server ([Kokoro TTS](https://github.com/remsky/Kokoro-FastAPI),
`OMP_NUM_THREADS=8`, container `--cpus 8`) starting from an idle box:

| Variant | Drops / runs | Time to drop |
|---|---|---|
| bursts of 8 requests arriving **over the wire** from another LAN host, random 1–12 s idle gaps | 6 / 6 | 16 s – 4.5 min |
| same bursts generated **locally** on the box | 1 / 4 | 20 s (the one) |
| same, but with the requests arriving over **Wi-Fi** and only an idle ssh session on the wire | 1 / 1 | 6 min |

So "the NIC is receiving something during the ramp" is necessary (an idle ssh
session satisfies it), and the ramp has to come from this kind of load. Two
kernels (7.1.7, 7.2.1) and two linux-firmware releases behave the same.

## 4. What does NOT trigger it

Each ≥ 12 min, most 15–25, same sampler, same box, same day. Scripts in
[not-reproducing/](not-reproducing/).

| Load | What it tests | Peak | Result |
|---|---|---|---|
| `avxburn avx512 24` steady, 20 min | sustained power at the PPT | 54 W, PHY 61 °C | clean |
| `avxburn` 24 threads, 8 s on / 4 s off ×120 | idle→full power transients (di/dt) | 54 W steps | clean |
| Kokoro ×8 **steady** loops + 144 GB download bound to the NIC, 25 min | the load, without the idle→burst edge, plus RX DMA | 50 W | clean |
| RX bursts (8 × 20 MB) from idle, no CPU load | inbound DMA burst alone | — | clean |
| `avxburn` bursts from idle + steady download on the NIC | CPU edge while the NIC is busy | 54 W | clean |
| RX burst and `avxburn` burst started at the same instant | synthetic "coincident wake" | 54 W | clean |
| box TX bursts to the client + inbound-ssh-triggered `avxburn` | inbound activity + CPU ramp, synthetic | 54 W | clean |
| inbound-triggered memory-bandwidth bursts (`stress-ng --vm`) | fabric/memory power instead of core power | — | clean |
| `stress-ng --matrix 24` bursts from idle | GEMM-shaped CPU+memory load | — | clean |
| `avxburn avx512 8 8` bursts from idle (8 threads) | few-core boost, steady | — | clean |
| faster-whisper (CTranslate2, AVX-512 VNNI) bursts, 24 threads | a different inference engine (the AQtion#74 reporter's load) | — | clean |
| `avxburn` under `CPUQuota=800%` | CFS-throttled bursts, like the container | — | clean |
| Kokoro bursts with the container's CPU quota removed / restored | quota as the variable | — | clean both ways (control) |
| 4 h of the reproducer with Wi-Fi as the box's route | (a different fault, not this one) | — | wire never involved |

Package power, clock, thread count, instruction width, DMA volume, DMA
direction, CFS throttling: none of them is the property. Something about a
PyTorch inference ramp is.

## 5. Mitigations tried

Reproducer running over the wire for every row; "fails" means it dropped.

| Mitigation | Idea | Result |
|---|---|---|
| keep the NIC busy (100 pps ping bound to it) | every steady-traffic test was clean | **fails**, 25 s |
| disable deep C-states (C2/C3 off) | SoC waking from deep idle | **fails**, 83 s |
| `energy_performance_preference=power`, no cap | gentler boost slope | **fails**, 10 min |
| `scaling_max_freq` 2.0 GHz (bursts ≤ 10 W) | halve the power step | **works**, clean 15 min |
| 3.0 GHz (≤ 17 W) | | **works**, clean 15 min |
| 4.0 GHz (≤ 23 W) | | **works**, clean 15 min |
| **uncapped control** between the caps | prove the caps were doing the work | **dropped in 16 s** (the `ffff` sample, §1) |
| **4.5 GHz (≤ 30 W)** | the highest cap that works | **works**, clean 15 min, then 30 min with the wire as the box's only route, then ~5 h of normal use |
| 4.5 GHz cap + the reproducer at 50 W peaks with the cap *removed* again | recheck the next day | dropped again (drop 11) — the cap is what prevents it |

The bracketing says the fault lives in the last 0.8 GHz of single-core boost
(5.3 → 4.5 GHz), where package power under this load goes from ~28 W to
47–50 W — a voltage knee, not a linear power effect. All-core clocks are
PPT-limited to ~3.8 GHz regardless, so the cap costs nothing measurable.

## 6. Hypotheses

| Hypothesis | For | Against | Status |
|---|---|---|---|
| NIC/PHY overheating | — | PHY 38–44 °C at every drop; 61 °C for 20 min clean | out |
| Sustained CPU power / PPT | — | 54 W for 20 min clean | out |
| CPU power transients alone | drops sit on a ramp edge | 120 idle→54 W steps clean; 8-thread boost steps clean | not sufficient |
| NIC DMA load | — | 144 GB clean; drops happened with the NIC nearly idle | out |
| PCIe link failure (root port ↔ NIC) | — | `LnkSta` trained through every drop; config space readable a sample later; rescan works | out — it is the chip, not the link |
| Chip-internal reset (firmware hangs on the way back) | `ffff` blink + MMIO all-ones + `Boot code hanged` + only a bus reset recovers | — | **this is the failure mode** |
| Board power delivery to the NIC (rail droop on the SoC boost knee) | fits "SoC ramp + NIC awake → chip resets, link stays trained"; 0.8 GHz cap removes it; Windows reports too | not directly measurable from software | **leading explanation** |
| Instruction mix (AVX-512 vs AVX2) | AQtion#74 reporter's `CT2_FORCE_CPU_ISA=AVX2` control | AVX-512 loads clean here; whisper (AVX-512 VNNI) clean | not supported |
| Faulty RAM | — | a bad DIMM was replaced before any of this | out |
| Kernel / driver version | — | 7.1.7 and 7.2.1 identical | out |

## 7. Open

**Why a PyTorch inference ramp?** The best guess from the data: the reproducer
produces *few-core boost jitter* — 64 OpenMP threads across 8 requests waking,
running short GEMMs, sleeping — so individual cores spike to 5.3 GHz/Vmax and
back many times per second on different cores, while the mean clock stays at
2–3.6 GHz. Every synthetic load here was "on for N seconds" (steady per-core
frequency). Next test on our side: `turbostat` at 50–100 ms during the ramp
to confirm the excursions, then a duty-cycling few-thread generator. If that
reproduces, the report becomes `cc pulse.c && ./pulse` and the RCA pointer
sharpens from "boost knee" to "few-core boost transients on the shared rail".

## Timeline

- 2026-08-18: two drops in a month of normal use, under a similar inference load.
- 2026-08-26/27: sustained load 150–245, CPU 90 °C, PHY 67 °C — wire *fine* (the outages that day were memory hangs).
- 2026-08-29 08:43–14:00: sampler live; 6 drops on demand; recovery proven.
- 2026-08-29 15:49–17:46: mitigations; cap bracketing; 4.5 GHz deployed; wire made the primary route again.
- 2026-08-29 21:07: cap lifted for another test; drop 11 at 45 W on the ramp; cap restored.
