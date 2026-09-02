#!/bin/sh

# If the Metrics API is not available, you can get an idea of the cpu and memory usage by
# running this script INSIDE THE TRAEFIK POD
#

repeat_sec=5
CORES=$(awk '{if($1=="max"){print 1}else{print int($1/$2)}}' /sys/fs/cgroup/cpu.max)

while true; do
  echo
  echo " ---------------------------------"
  echo
  # CPU
  usage1=$(awk '/usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat)
  time1=$(awk '{print $1}' /proc/uptime)
  sleep 1
  usage2=$(awk '/usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat)
  time2=$(awk '{print $1}' /proc/uptime)
  cpu_percent=$(awk -v u1="$usage1" -v u2="$usage2" -v t1="$time1" -v t2="$time2" -v c="$CORES" '
  BEGIN {
      delta_usage_sec = (u2 - u1) / 1000000
      delta_time_sec = t2 - t1
      if (delta_time_sec > 0 && c > 0) {
          printf "%.2f", (delta_usage_sec / (delta_time_sec * c)) * 100
      } else {
          printf "0.00"
      }
  }')
  echo "CPU usage:"
  echo "    ${cpu_percent}% of $CORES cores"
  # MEM
  mem_used=$(cat /sys/fs/cgroup/memory.current 2>/dev/null)
  mem_max=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
  if [ "$mem_max" = "max" ]; then echo "No memory limit set (unlimited)"
  else
    mem_pct=$(awk -v u=$mem_used -v m=$mem_max 'BEGIN { printf "%.2f", (u/m)*100 }')
    mem_gib=$(awk -v m=$mem_max 'BEGIN { printf "%.2f", m/1024/1024/1024 }')
    echo "Working Memory usage:"
    echo "    $mem_pct% of $mem_gib GiB"
  fi
  sleep $repeat_sec
done
