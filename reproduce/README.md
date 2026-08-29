# Reproduce

1. On the box, as root: `box/run-kokoro.sh`, then `box/monitor.sh &`.
2. On another machine on the wired LAN: `BOX=<address> USER=<user> client/bursts.sh`.
   Passwordless ssh to the box is required (the tunnel is what puts the
   requests on the wire).
3. Watch `monitor.log` on the box, or `dmesg -w | grep atlantic`.
4. After the drop: `box/recover.sh`.

To confirm the workaround, run `../workaround/cap-boost.sh` first and repeat
step 2 for 15 min; then undo the cap (`cpupower frequency-set -u 5.3GHz`, or
reboot) and repeat — the second run drops.

Tuning knobs: `SECS` (default 1500), `BURST` (8), `GAPMAX` (12). The idle gap
matters: it is the idle→boost edge that does it, not the load itself.
