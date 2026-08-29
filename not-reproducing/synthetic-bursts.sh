#!/usr/bin/env bash
# synthetic bursts from idle with a configurable load command. No inference, no network.
#   BURSTCMD  the command run per burst (default: stress-ng matrix, a GEMM-shaped CPU+memory load)
set -u; SECS=${SECS:-900}; GAPMAX=${GAPMAX:-12}
BURSTCMD=${BURSTCMD:-stress-ng --matrix 24 --matrix-size 512 --matrix-method prod -t 8 -q}
end=$(( $(date +%s) + SECS )); n=0
while [ $(date +%s) -lt $end ]; do sleep $(( RANDOM % GAPMAX + 1 )); $BURSTCMD; n=$((n+1)); done
echo "done: $n bursts of: $BURSTCMD"
