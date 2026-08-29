#!/usr/bin/env bash
# Load-transient test: hammer the power rails with load onset/offset edges.
# CYCLES bursts of avxburn <MODE> on all threads for ON seconds, idle OFF seconds.
# A steady 54 W did nothing (T1); this is the di/dt version of the same idea.
set -u
MODE=${MODE:-avx512}; THREADS=${THREADS:-24}; ON=${ON:-8}; OFF=${OFF:-4}; CYCLES=${CYCLES:-120}
for i in $(seq 1 $CYCLES); do
  avxburn $MODE $THREADS $ON >/dev/null
  sleep $OFF
done
echo "transient done mode=$MODE threads=$THREADS on=$ON off=$OFF cycles=$CYCLES"
