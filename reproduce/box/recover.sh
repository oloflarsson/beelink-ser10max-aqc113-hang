#!/usr/bin/env bash
# Bring the NIC back after a drop, escalating. Only step 3 has ever worked
# (10 of 10, 45–53 s); steps 1–2 are kept to show that they do not. Run as root.
set -u
IFACE=${IFACE:-eno1}; PCI=${PCI:-0000:c3:00.0}
up() { [ "$(cat /sys/class/net/$IFACE/carrier 2>/dev/null)" = 1 ]; }
echo "step 1/3: ip link down/up"; ip link set $IFACE down; sleep 2; ip link set $IFACE up; sleep 8
up && { echo "recovered after step 1"; exit 0; }
echo "step 2/3: ethtool -r"; ethtool -r $IFACE; sleep 10
up && { echo "recovered after step 2"; exit 0; }
echo "step 3/3: PCI remove + rescan of $PCI"
echo 1 > /sys/bus/pci/devices/$PCI/remove; sleep 3; echo 1 > /sys/bus/pci/rescan; sleep 15
up && { echo "recovered after step 3 (PCI rescan)"; exit 0; }
echo "still down — power cycle"; exit 1
