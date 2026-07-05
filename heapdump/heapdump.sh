#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <PID> [OUTPUT_DIR]"
    exit 1
fi

PID=$1
OUTPUT_DIR=${2:-/tmp}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HEAP_DUMP_FILE="${OUTPUT_DIR}/heapdump_${PID}_${TIMESTAMP}.hprof"

echo "Taking heap dump for PID: $PID"
jcmd $PID GC.heap_dump "$HEAP_DUMP_FILE"

if [ $? -eq 0 ]; then
    echo "Heap dump created successfully:"
    echo "$HEAP_DUMP_FILE"
else
    echo "Heap dump failed."
fi
