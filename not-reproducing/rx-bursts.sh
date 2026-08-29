#!/usr/bin/env bash
# RX bursts through eno1 into an otherwise idle box. No inference load.
set -u; SECS=${SECS:-720}; BURST=${BURST:-8}; GAPMAX=${GAPMAX:-12}
end=$(( $(date +%s) + SECS )); n=0
while [ $(date +%s) -lt $end ]; do
  sleep $(( RANDOM % GAPMAX + 1 ))
  for i in $(seq 1 $BURST); do curl -s -m 60 --interface ${BOX_IP:?wired address of the NIC under test} -o /dev/null -r 0-20000000 http://speedtest.tele2.net/100MB.zip & done
  wait; n=$((n+1))
done
echo "done: $n bursts"
