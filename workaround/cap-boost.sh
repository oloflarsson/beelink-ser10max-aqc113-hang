#!/usr/bin/env bash
# Cap every CPU's boost ceiling at 4.5 GHz. Lasts until reboot. Run as root.
# Bracketed on the SER10 MAX: 2.0/3.0/4.0/4.5 GHz all prevent the hang,
# uncapped drops in seconds. All-core is PPT-limited to ~3.8 GHz anyway, so
# this only trims single-thread boost (5.3 → 4.5 GHz).
set -eu
MAX=${MAX:-4500000}
for c in /sys/devices/system/cpu/cpu*/cpufreq; do echo $MAX > $c/scaling_max_freq; done
echo "scaling_max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq) on $(ls -d /sys/devices/system/cpu/cpu*/cpufreq | wc -l) CPUs"
# equivalent: cpupower frequency-set -u 4.5GHz
