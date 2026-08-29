# Loads that did NOT reproduce the hang

All run on the SER10 MAX on 2026-08-29 with the same sampler as the
reproducer, ≥ 12 min each (most 15–25). Zero drops. Kept so nobody repeats
them, and because "not that" is most of what is known about the trigger.

| Script | Idea | Peak | Result |
|---|---|---|---|
| `avxburn avx512 24 1200` | steady all-core AVX-512 FMA, register-only: the highest-power instruction mix, 20 min | 54 W, PHY 61 °C | clean |
| `transients.sh` | the same, 8 s on / 4 s off × 120 — idle→full power edges (di/dt) | 54 W steps | clean |
| `steady-kokoro-plus-rx.sh` | the reproducer's load run **steadily** (8 request loops, no idle gaps) plus 144 GB downloaded through the NIC | 50 W | clean |
| `rx-bursts.sh` | 8 × 20 MB downloads from idle, no CPU load — inbound DMA bursts alone | — | clean |
| `cpu-steps-steady-rx.sh` | `avxburn` bursts from idle while a download runs continuously on the NIC | 54 W | clean |
| `coincident-rx-and-cpu.sh` | an RX burst and a full-power CPU burst started at the same instant | 54 W | clean |
| `client-tx-bursts-inbound-cpu.sh` (runs on the client) | the box sends 8 × 20 MB while an inbound ssh triggers a CPU burst — inbound activity + ramp, synthetic | 54 W | clean; also with `CPUCMD="stress-ng --vm 8 --vm-bytes 1G -t 6"` (memory bandwidth) |
| `synthetic-bursts.sh` | `stress-ng --matrix 24` bursts from idle (GEMM-shaped CPU+memory); `BURSTCMD` selectable | — | clean; also `avxburn avx512 8 8` (few-core boost) and `avxburn` under `CPUQuota=800%` |
| `whisper-bursts.sh` + `whisper.py` | faster-whisper (CTranslate2, AVX-512 VNNI) bursts — the load in AQtion#74 | — | clean |
| `local-kokoro-bursts.sh` | the reproducer's bursts generated **on the box**, nothing inbound | 47 W | 1 drop in 4 runs — works, but unreliably; the over-the-wire form is 6/6 |

`avxburn`: `cc -O2 -pthread -mavx512f -mavx2 -mfma -o avxburn avxburn.c`;
`avxburn avx512|avx2|scalar <threads> <seconds>`.

Environment variables are at the top of each script (`SECS`, `GAPMAX`, `BURST`,
`BOX_IP` for the scripts that bind to the NIC's address).
