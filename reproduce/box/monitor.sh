#!/usr/bin/env bash
# 2 s samples of everything that mattered, one line each, key=value. Run as root.
#   package power (RAPL, mW), mean CPU MHz, k10temp, NIC PHY/MAC temp, NVMe temp,
#   NIC carrier/speed/operstate, a 1-packet ping to the gateway bound to the NIC,
#   the root-port/device LnkSta (setpci), the device vendor ID (ffff = config
#   space dead), and the kernel's running count of link drops this boot.
# Usage: IFACE=eno1 PCI=0000:c3:00.0 GW=<gateway> LOG=./monitor.log monitor.sh
set -u
IFACE=${IFACE:-eno1}; PCI=${PCI:-0000:c3:00.0}; LOG=${LOG:-./monitor.log}
GW=${GW:-$(ip route show default dev "$IFACE" 2>/dev/null | awk '{print $3; exit}')}
RAPL=/sys/class/powercap/intel-rapl:0/energy_uj
prev_e=$(cat $RAPL 2>/dev/null || echo 0); prev_t=$(date +%s%N)
hw() { for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat $h/name 2>/dev/null)" = "$1" ] && { v=$(cat $h/${2:-temp1_input} 2>/dev/null); echo $((v/1000)); return; }
      done; echo -; }
while :; do
  now=$(date +%Y-%m-%dT%H:%M:%S)
  e=$(cat $RAPL 2>/dev/null || echo 0); t=$(date +%s%N)
  pw=$(( (e-prev_e) / ( (t-prev_t)/1000000 + 1 ) )); [ $pw -lt 0 ] && pw=-
  prev_e=$e; prev_t=$t
  mhz=$(awk '/cpu MHz/{s+=$4;n++}END{printf "%d",s/n}' /proc/cpuinfo)
  load=$(cut -d" " -f1 /proc/loadavg)
  c=$(cat /sys/class/net/$IFACE/carrier 2>/dev/null || echo -)
  s=$(cat /sys/class/net/$IFACE/speed 2>/dev/null || echo -)
  o=$(cat /sys/class/net/$IFACE/operstate 2>/dev/null || echo -)
  drops=$(dmesg 2>/dev/null | grep -c "link change old [0-9]* new 0")
  p=$(ping -c1 -W1 -I $IFACE $GW >/dev/null 2>&1 && echo ok || echo FAIL)
  echo "t=$now load=$load mW=$pw mhz=$mhz cpu=$(hw k10temp)C phy=$(hw $IFACE)C mac=$(hw $IFACE temp2_input)C nvme=$(hw nvme)C | $IFACE carrier=$c speed=$s op=$o ping=$p lnk=$(setpci -s $PCI CAP_EXP+12.w 2>/dev/null) vid=$(setpci -s $PCI 0.w 2>/dev/null) drops=$drops" >> "$LOG"
  sleep 2
done
