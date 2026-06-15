#!/bin/bash

# Usage:
# ./multi_pid_threaddump.sh "1234 5678" 5 1
#
# "1234 5678" = Java PIDs
# 5 = number of thread dumps
# 1 = interval in seconds

PIDS=$1
COUNT=$2
INTERVAL=$3

if [ -z "$PIDS" ] || [ -z "$COUNT" ] || [ -z "$INTERVAL" ]; then
  echo "Usage: $0 \"PID1 PID2\" <dump_count> <interval_seconds>"
  exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="thread_dumps_$TIMESTAMP"

mkdir -p "$OUTPUT_DIR"

echo "Taking $COUNT thread dumps for PIDs: $PIDS"
echo "Interval: $INTERVAL seconds"
echo "Output directory: $OUTPUT_DIR"

for i in $(seq 1 "$COUNT"); do
  echo "Dump number: $i"

  for PID in $PIDS; do
    echo "Taking thread dump for PID: $PID"
    jstack -l "$PID" > "$OUTPUT_DIR/thread_dump_pid_${PID}_${i}.txt"
  done

  sleep "$INTERVAL"
done

echo "Thread dumps completed."
