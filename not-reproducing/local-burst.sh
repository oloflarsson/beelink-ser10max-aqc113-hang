#!/usr/bin/env bash
# one burst of N parallel local Kokoro requests
N=${1:-8}
TEXT="Bursty request number arriving over the wire into an idle box. The link should survive this, but it does not."
for i in $(seq 1 $N); do curl -s -m 120 -o /dev/null localhost:8880/v1/audio/speech -H "Content-Type: application/json" -d "{\"model\":\"kokoro\",\"input\":\"$TEXT $i\",\"voice\":\"af_heart\",\"response_format\":\"wav\"}" & done; wait
