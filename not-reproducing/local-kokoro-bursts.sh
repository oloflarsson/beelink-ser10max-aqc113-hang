#!/usr/bin/env bash
# local Kokoro bursts from idle on a local timer. No inbound traffic at all.
set -u; SECS=${SECS:-900}; N=${N:-8}; GAPMAX=${GAPMAX:-12}
end=$(( $(date +%s) + SECS )); n=0
while [ $(date +%s) -lt $end ]; do sleep $(( RANDOM % GAPMAX + 1 )); ./local-burst.sh $N; n=$((n+1)); done
echo "done: $n bursts"
