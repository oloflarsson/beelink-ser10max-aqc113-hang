#!/usr/bin/env bash
# Runs on the CLIENT. Bursty requests that ARRIVE OVER THE WIRE: an ssh tunnel
# to the box carries request and response through its wired NIC. Pattern:
# idle 1–GAPMAX s (random), then BURST parallel requests, repeat for SECS.
#   BOX=<box wired address>  USER=<ssh user>  SECS=1500 BURST=8 GAPMAX=12
set -u
BOX=${BOX:?set BOX to the box's wired LAN address}; USER=${USER:-$LOGNAME}
SECS=${SECS:-1500}; BURST=${BURST:-8}; GAPMAX=${GAPMAX:-12}
ssh -o BatchMode=yes -N -L 18880:127.0.0.1:8880 "$USER@$BOX" & TUN=$!
sleep 2
end=$(( $(date +%s) + SECS )); n=0
TEXT="Bursty request number arriving over the wire into an idle box. The link should survive this, but it does not."
while [ $(date +%s) -lt $end ]; do
  sleep $(( RANDOM % GAPMAX + 1 ))
  for i in $(seq 1 $BURST); do
    curl -s -m 120 -o /dev/null localhost:18880/v1/audio/speech -H "Content-Type: application/json" \
      -d "{\"model\":\"kokoro\",\"input\":\"$TEXT $n\",\"voice\":\"af_heart\",\"response_format\":\"wav\"}" &
  done
  wait $(jobs -p | grep -v $TUN) 2>/dev/null
  n=$((n+1))
  # the tunnel dies with the link; that is the signal
  kill -0 $TUN 2>/dev/null || { echo "tunnel gone after $n bursts — check the box's monitor.log"; exit 0; }
done
kill $TUN; echo "done: $n bursts of $BURST, no drop"
