#!/usr/bin/env bash
# CPU power steps (avxburn bursts from idle) while eno1 carries a STEADY download.
# Separates "CPU boost edge while the NIC is busy" from "burst of RX arriving".
set -u; SECS=${SECS:-720}; ON=${ON:-6}; GAPMAX=${GAPMAX:-12}
end=$(( $(date +%s) + SECS ))
( while [ $(date +%s) -lt $end ]; do curl -s -m 120 --interface ${BOX_IP:?wired address of the NIC under test} -o /dev/null http://speedtest.tele2.net/100MB.zip; done ) &
n=0
while [ $(date +%s) -lt $end ]; do
  sleep $(( RANDOM % GAPMAX + 1 ))
  avxburn avx512 24 $ON >/dev/null; n=$((n+1))
done
wait; echo "done: $n CPU bursts"
