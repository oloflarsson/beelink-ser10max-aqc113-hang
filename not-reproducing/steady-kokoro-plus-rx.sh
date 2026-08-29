#!/usr/bin/env bash
# the 08-18 trigger — Kokoro TTS, N parallel request loops, for SECS seconds.
# Optional: TRAFFIC_URL pulled in a loop bound to the wired address, so the
# AQC113 does real RX DMA under the load like it did on 08-18.
set -u
N=${N:-8}; SECS=${SECS:-1500}; TRAFFIC_URL=${TRAFFIC_URL:-}
WIRED_IP=${WIRED_IP:-${BOX_IP:?wired address of the NIC under test}}
end=$(( $(date +%s) + SECS ))
TEXT="The quick brown fox jumps over the lazy dog while the network card drops its link and never comes back. This sentence exists to keep the synthesizer busy for a few seconds per request."
worker() {
  local n=0
  while [ $(date +%s) -lt $end ]; do
    curl -s -m 120 -o /dev/null localhost:8880/v1/audio/speech -H "Content-Type: application/json" \
      -d "{\"model\":\"kokoro\",\"input\":\"$TEXT\",\"voice\":\"af_heart\",\"response_format\":\"wav\"}" && n=$((n+1))
  done
  echo "worker $1 done $n requests"
}
for i in $(seq 1 $N); do worker $i & done
if [ -n "$TRAFFIC_URL" ]; then
  ( b=0; while [ $(date +%s) -lt $end ]; do curl -s -m 120 --interface $WIRED_IP -o /dev/null -w "%{size_download}\n" "$TRAFFIC_URL"; done | awk '{s+=$1}END{printf "traffic done %.1f GB via eno1\n", s/1e9}' ) &
fi
wait
echo "done"
