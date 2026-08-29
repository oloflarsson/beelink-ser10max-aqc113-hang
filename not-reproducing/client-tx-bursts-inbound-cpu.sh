#!/usr/bin/env bash
# (Mac side): after a random idle gap, pull BURST x 20 MB from the box over eno1
# (box TX) and, at the same instant, trigger a CPU burst on the box via an inbound ssh.
set -u; SECS=${SECS:-720}; BURST=${BURST:-8}; GAPMAX=${GAPMAX:-12}; CPU=${CPU:-1}
H=${USER:-$LOGNAME}@${BOX_IP:?wired address}
while [ $(date +%s) -lt $end ]; do
  sleep $(( RANDOM % GAPMAX + 1 ))
  for i in $(seq 1 $BURST); do ssh -o BatchMode=yes -o ConnectTimeout=5 $H 'cat /tmp/blob   # a 20 MB file on the box' > /dev/null 2>&1 & done
  [ "$CPU" = 1 ] && ssh -o BatchMode=yes -o ConnectTimeout=5 $H "${CPUCMD:-avxburn avx512 24 6}" > /dev/null 2>&1 &
  wait; n=$((n+1))
done
echo "done: $n bursts (cpu=$CPU)"
