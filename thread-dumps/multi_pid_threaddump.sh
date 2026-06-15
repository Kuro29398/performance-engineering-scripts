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
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"

mkdir -p "$OUTPUT_DIR"

echo "Thread Dump Collection Summary" > "$SUMMARY_FILE"
echo "Started At       : $(date)" >> "$SUMMARY_FILE"
echo "Host             : $(hostname)" >> "$SUMMARY_FILE"
echo "PIDs             : $PIDS" >> "$SUMMARY_FILE"
echo "Dump Count       : $COUNT" >> "$SUMMARY_FILE"
echo "Interval Seconds : $INTERVAL" >> "$SUMMARY_FILE"
echo "Output Directory : $OUTPUT_DIR" >> "$SUMMARY_FILE"
echo "----------------------------------------" >> "$SUMMARY_FILE"

echo "Taking $COUNT thread dumps for PIDs: $PIDS"
echo "Interval: $INTERVAL seconds"
echo "Output directory: $OUTPUT_DIR"

for i in $(seq 1 "$COUNT"); do
  echo "Dump number: $i"

  for PID in $PIDS; do

    if ! ps -p "$PID" > /dev/null 2>&1; then
      echo "PID $PID not found. Skipping."
      echo "Dump $i | PID $PID | Status: PID not found" >> "$SUMMARY_FILE"
      continue
    fi

    DUMP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    THREAD_DUMP_FILE="$OUTPUT_DIR/thread_dump_pid_${PID}_${DUMP_TIMESTAMP}_dump_${i}.txt"
    TOP_FILE="$OUTPUT_DIR/top_pid_${PID}_${DUMP_TIMESTAMP}_dump_${i}.txt"

    echo "Taking thread dump for PID: $PID"

    jstack -l "$PID" > "$THREAD_DUMP_FILE" 2>&1
    top -b -n 1 -p "$PID" > "$TOP_FILE" 2>&1

    echo "Dump $i | PID $PID | ThreadDump: $THREAD_DUMP_FILE | Top: $TOP_FILE | Status: Completed" >> "$SUMMARY_FILE"
  done

  sleep "$INTERVAL"
done

echo "Completed At     : $(date)" >> "$SUMMARY_FILE"
echo "Thread dumps completed."
