```bash
#!/usr/bin/env bash

# Multi-PID Java Thread Dump Collector
#
# Usage:
#   ./multi_pid_threaddump.sh -p "1234 5678" -c 5 -i 10
#   ./multi_pid_threaddump.sh -a -c 5 -i 10
#
# Options:
#   -p  Java PIDs
#   -a  Automatically detect Java PIDs
#   -c  Number of dumps
#   -i  Interval in seconds
#   -o  Output directory
#   -z  Compress output files
#   -h  Show help

set -uo pipefail

PIDS=""
AUTO_DISCOVER=0
COUNT=5
INTERVAL=10
OUTPUT_DIR=""
GZIP=0
COMMAND_TIMEOUT=30
MIN_FREE_MB=200

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
    echo "Usage:"
    echo "  $0 -p \"PID1 PID2\" -c <count> -i <interval>"
    echo "  $0 -a -c <count> -i <interval>"
    echo
    echo "Options:"
    echo "  -p, --pids         Java PIDs"
    echo "  -a, --all          Detect all Java PIDs"
    echo "  -c, --count        Number of dumps (default: 5)"
    echo "  -i, --interval     Interval in seconds (default: 10)"
    echo "  -o, --output-dir   Output directory"
    echo "  -z, --gzip         Compress output files"
    echo "  -h, --help         Show help"
}

is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_with_timeout() {
    if command_exists timeout; then
        timeout "$COMMAND_TIMEOUT" "$@"
    else
        "$@"
    fi
}

check_dependencies() {
    for command in ps date df awk; do
        command_exists "$command" || {
            log "ERROR: Missing command: $command"
            exit 1
        }
    done

    if command_exists jcmd; then
        DUMP_TOOL="jcmd"
    elif command_exists jstack; then
        DUMP_TOOL="jstack"
    else
        log "ERROR: jcmd or jstack is required."
        exit 1
    fi

    if command_exists top; then
        HAVE_TOP=1
    else
        HAVE_TOP=0
        log "WARNING: top not found. CPU snapshots will be skipped."
    fi
}

check_disk_space() {
    local available_mb

    available_mb=$(df -Pm "$OUTPUT_DIR" | awk 'NR==2 {print $4}')

    if [[ -n "$available_mb" && "$available_mb" -lt "$MIN_FREE_MB" ]]; then
        log "ERROR: Only ${available_mb} MB disk space available."
        exit 1
    fi
}

compress_file() {
    local file="$1"

    if [[ "$GZIP" -eq 1 && -f "$file" ]]; then
        gzip -f "$file"
    fi
}

discover_pids() {
    command_exists jps || {
        log "ERROR: jps is required for automatic PID detection."
        exit 1
    }

    jps -q | tr '\n' ' '
}

capture_pid() {
    local dump_number="$1"
    local pid="$2"
    local timestamp
    local prefix
    local thread_file
    local top_file
    local process_file
    local status="completed"

    if ! kill -0 "$pid" 2>/dev/null; then
        log "WARNING: PID $pid not found."
        echo "Dump $dump_number | PID $pid | Status: PID not found" >> "$SUMMARY_FILE"
        return
    fi

    timestamp=$(date +"%Y%m%d_%H%M%S")
    prefix="$OUTPUT_DIR/pid_${pid}_dump_${dump_number}_${timestamp}"

    thread_file="${prefix}_thread_dump.txt"
    top_file="${prefix}_top_threads.txt"
    process_file="${prefix}_process_details.txt"

    log "Collecting dump $dump_number for PID $pid."

    {
        echo "Process Details"
        echo "==============="
        ps -p "$pid" \
            -o pid=,ppid=,user=,stat=,etimes=,%cpu=,%mem=,rss=,vsz=,nlwp=,cmd=
    } > "$process_file" 2>&1

    if [[ "$DUMP_TOOL" == "jcmd" ]]; then
        run_with_timeout jcmd "$pid" Thread.print -l > "$thread_file" 2>&1 ||
            status="thread_dump_failed"
    else
        run_with_timeout jstack -l "$pid" > "$thread_file" 2>&1 ||
            status="thread_dump_failed"
    fi

    if [[ "$HAVE_TOP" -eq 1 ]]; then
        run_with_timeout top -H -b -n 1 -p "$pid" > "$top_file" 2>&1
    else
        echo "top command is not available." > "$top_file"
    fi

    compress_file "$thread_file"
    compress_file "$top_file"
    compress_file "$process_file"

    echo "Dump $dump_number | PID $pid | Tool: $DUMP_TOOL | Status: $status" \
        >> "$SUMMARY_FILE"

    log "PID $pid completed with status: $status."
}

cleanup() {
    local exit_code=$?

    if [[ "${COMPLETED:-0}" -ne 1 ]]; then
        echo "Interrupted At    : $(date)" >> "$SUMMARY_FILE"
        log "Collection interrupted. Partial results are available in $OUTPUT_DIR."
    fi

    exit "$exit_code"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--pids)
            PIDS="${2:-}"
            shift 2
            ;;
        -a|--all)
            AUTO_DISCOVER=1
            shift
            ;;
        -c|--count)
            COUNT="${2:-}"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="${2:-}"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="${2:-}"
            shift 2
            ;;
        -z|--gzip)
            GZIP=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR: Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

is_positive_integer "$COUNT" || {
    log "ERROR: Count must be a positive integer."
    exit 1
}

is_positive_integer "$INTERVAL" || {
    log "ERROR: Interval must be a positive integer."
    exit 1
}

check_dependencies

if [[ "$AUTO_DISCOVER" -eq 1 ]]; then
    PIDS=$(discover_pids)
fi

if [[ -z "$PIDS" ]]; then
    log "ERROR: Provide PIDs using -p or use -a."
    usage
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
HOSTNAME_VALUE=$(hostname 2>/dev/null || echo "unknown")
OUTPUT_DIR="${OUTPUT_DIR:-thread_dumps_${HOSTNAME_VALUE}_${TIMESTAMP}}"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"

mkdir -p "$OUTPUT_DIR" || {
    log "ERROR: Cannot create output directory."
    exit 1
}

trap cleanup EXIT
trap 'exit 130' INT TERM

{
    echo "Thread Dump Collection Summary"
    echo "========================================"
    echo "Started At       : $(date)"
    echo "Host             : $HOSTNAME_VALUE"
    echo "PIDs             : $PIDS"
    echo "Dump Count       : $COUNT"
    echo "Interval Seconds : $INTERVAL"
    echo "Dump Tool        : $DUMP_TOOL"
    echo "Gzip Enabled     : $GZIP"
    echo "Output Directory : $OUTPUT_DIR"
    echo "========================================"
} > "$SUMMARY_FILE"

log "Starting thread dump collection."
log "PIDs: $PIDS"
log "Output directory: $OUTPUT_DIR"

for ((dump_number = 1; dump_number <= COUNT; dump_number++)); do
    log "Starting dump round $dump_number of $COUNT."

    check_disk_space

    background_jobs=()

    for pid in $PIDS; do
        if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
            log "WARNING: Invalid PID: $pid"
            continue
        fi

        capture_pid "$dump_number" "$pid" &
        background_jobs+=("$!")
    done

    for job in "${background_jobs[@]}"; do
        wait "$job"
    done

    if ((dump_number < COUNT)); then
        sleep "$INTERVAL"
    fi
done

{
    echo "========================================"
    echo "Completed At     : $(date)"
} >> "$SUMMARY_FILE"

COMPLETED=1
trap - EXIT

log "Thread dump collection completed."
log "Summary file: $SUMMARY_FILE"
```
