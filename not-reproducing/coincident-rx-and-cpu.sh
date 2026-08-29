#!/usr/bin/env bash
# synthetic coincident wake-up. After a random idle gap, start an RX burst on the
# wired NIC AND a full-power CPU burst at the same instant. No inference, no peer needed.
set -u; SECS=${SECS:-720}; BURST=${BURST:-8}; ON=${ON:-6}; GAPMAX=${GAPMAX:-12}
WIRED_IP=${WIRED_IP:-${BOX_IP:?wired address of the NIC under test}}; URL=${URL:-http://speedtest.tele2.net/100MB.zip}
end=$(( $(date +%s) + SECS )); n=0
while [ $(date +%s) -lt $end ]; do
  sleep $(( RANDOM % GAPMAX + 1 ))
  for i in $(seq 1 $BURST); do curl -s -m 60 --interface $WIRED_IP -o /dev/null -r 0-20000000 "$URL" & done
  avxburn avx512 24 $ON >/dev/null &
  wait; n=$((n+1))
done
echo "done: $n coincident bursts"
