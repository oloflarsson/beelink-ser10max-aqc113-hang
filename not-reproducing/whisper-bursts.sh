#!/usr/bin/env bash
# faster-whisper (CTranslate2) bursts from idle — the AQtion #74 reporter workload, pip-installable.
set -u; SECS=${SECS:-900}; GAPMAX=${GAPMAX:-12}; THREADS=${THREADS:-24}; MODEL=${MODEL:-small}
PY=${PY:-python3}   # with faster-whisper installed
end=$(( $(date +%s) + SECS )); n=0
while [ $(date +%s) -lt $end ]; do
  sleep $(( RANDOM % GAPMAX + 1 ))
  MODEL=$MODEL THREADS=$THREADS SECS=6 $PY ./whisper.py /tmp/k.wav >/dev/null 2>&1
  n=$((n+1))
done
echo "done: $n whisper bursts"
