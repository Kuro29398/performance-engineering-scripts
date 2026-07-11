#!/usr/bin/env bash

# =============================================================================
# Multi-PID Java Thread Dump Collector
#
# Usage:
#   ./multi_pid_threaddump.sh "1234 5678" 5 10
#
# Arguments:
#   1. Space-separated Java PIDs
#   2. Number of dumps
#   3. Interval between dump cycles in seconds
#
# Example:
#   ./multi_pid_threaddump.sh "1234 5678" 5 10
# =============================================================================

set -u
set -o pipefail

readonly SCRIPT_NAME=$(basename "$0")
readonly COMMAND_TIMEOUT=30

PIDS_INPUT="${1:-}"
COUNT="${2:-}"
INTERVAL="${3:-}"

print_usage() {
    echo "Usage: $SCRIPT_NAME \"PID1 PID2\" <dump_count> <interval_seconds>"
    echo
    echo "Example:"
    echo "  $SCRIPT_NAME \"1234 5678\" 5 10"
}

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_non_negative_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Validate input
# -----------------------------------------------------------------------------

if [[ -z "$PIDS_INPUT" || -z "$COUNT" || -z "$INTERVAL" ]]; then
    print_usage
    exit 1
fi

is_positive_integer "$COUNT" ||
    fail "Dump count must be a positive integer."

is_non_negative_number "$INTERVAL" ||
    fail "Interval must be a non-negative number."

read -r -a PIDS <<< "$PIDS_INPUT"

if [[ ${#PIDS[@]} -eq 0 ]]; then
    fail "At least one PID must be provided."
fi

for PID in "${PIDS[@]}"; do
    [[ "$PID" =~ ^[0-9]+$ ]] ||
        fail "Invalid PID: $PID"
done

# -----------------------------------------------------------------------------
# Validate required commands
# -----------------------------------------------------------------------------

command_exists ps || fail "'ps' command is not available."
command_exists top || fail "'top' command is not available."

if command_exists jcmd; then
    readonly DUMP_TOOL="jcmd"
elif command_exists jstack; then
    readonly DUMP_TOOL="jstack"
else
    fail "Neither 'jcmd' nor 'jstack' is available. Install or configure the JDK."
fi

if command_exists timeout; then
    readonly HAS_TIMEOUT=true
else
    readonly HAS_TIMEOUT=false
    log "WARNING: 'timeout' command not found. Command timeout protection is disabled."
fi

# -----------------------------------------------------------------------------
# Prepare output directory
# -----------------------------------------------------------------------------

readonly START_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
readonly HOST_NAME=$(hostname 2>/dev/null || echo "unknown-host")
readonly OUTPUT_DIR="thread_dumps_${HOST_NAME}_${START_TIMESTAMP}"
readonly SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
readonly ERROR_FILE="$OUTPUT_DIR/errors.log"

mkdir -p "$OUTPUT_DIR" ||
    fail "Unable to create output directory: $OUTPUT_DIR"

# -----------------------------------------------------------------------------
# Cleanup and interrupt handling
# -----------------------------------------------------------------------------

INTERRUPTED=false

handle_interrupt() {
    INTERRUPTED=true
    log "Interrupt received. Stopping collection safely."
}

trap handle_interrupt INT TERM

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

run_with_timeout() {
    if [[ "$HAS_TIMEOUT" == true ]]; then
        timeout "$COMMAND_TIMEOUT" "$@"
    else
        "$@"
    fi
}

is_process_running() {
    kill -0 "$1" 2>/dev/null
}

is_java_process() {
    local pid="$1"
    local command_name

    command_name=$(ps -p "$pid" -o comm= 2>/dev/null || true)

    [[ "$command_name" =~ java ]]
}

get_process_start_time() {
    ps -p "$1" -o lstart= 2>/dev/null |
        sed 's/^[[:space:]]*//' || true
}

collect_thread_dump() {
    local pid="$1"
    local output_file="$2"

    if [[ "$DUMP_TOOL" == "jcmd" ]]; then
        run_with_timeout jcmd "$pid" Thread.print -l > "$output_file" 2>&1
    else
        run_with_timeout jstack -l "$pid" > "$output_file" 2>&1
    fi
}

collect_process_details() {
    local pid="$1"
    local output_file="$2"

    {
        echo "Process Details"
        echo "==============="
        echo

        ps -p "$pid" \
            -o pid=,ppid=,user=,stat=,etimes=,%cpu=,%mem=,rss=,vsz=,nlwp=,cmd=

        echo
        echo "Process Start Time:"
        get_process_start_time "$pid"
    } > "$output_file" 2>&1
}

collect_top_snapshot() {
    local pid="$1"
    local output_file="$2"

    # -H shows individual Java threads, useful for correlating native thread IDs.
    run_with_timeout top -H -b -n 1 -p "$pid" > "$output_file" 2>&1
}

write_summary_header() {
    {
        echo "Thread Dump Collection Summary"
        echo "========================================"
        echo "Started At        : $(date)"
        echo "Host              : $HOST_NAME"
        echo "User              : $(id -un 2>/dev/null || echo unknown)"
        echo "Operating System  : $(uname -a)"
        echo "PIDs              : ${PIDS[*]}"
        echo "Dump Count        : $COUNT"
        echo "Interval Seconds  : $INTERVAL"
        echo "Thread Dump Tool  : $DUMP_TOOL"
        echo "Command Timeout   : ${COMMAND_TIMEOUT}s"
        echo "Output Directory  : $OUTPUT_DIR"
        echo "========================================"
    } > "$SUMMARY_FILE"
}

# -----------------------------------------------------------------------------
# Start collection
# -----------------------------------------------------------------------------

write_summary_header

SUCCESS_COUNT=0
FAILURE_COUNT=0
SKIPPED_COUNT=0

log "Starting thread dump collection."
log "PIDs: ${PIDS[*]}"
log "Dump cycles: $COUNT"
log "Interval: ${INTERVAL}s"
log "Dump tool: $DUMP_TOOL"
log "Output directory: $OUTPUT_DIR"

for ((dump_number = 1; dump_number <= COUNT; dump_number++)); do

    if [[ "$INTERRUPTED" == true ]]; then
        break
    fi

    log "Starting dump cycle $dump_number of $COUNT."

    for PID in "${PIDS[@]}"; do

        if [[ "$INTERRUPTED" == true ]]; then
            break
        fi

        if ! is_process_running "$PID"; then
            log "WARNING: PID $PID does not exist. Skipping."

            printf 'Dump %s | PID %s | Status: PID not found\n' \
                "$dump_number" "$PID" >> "$SUMMARY_FILE"

            ((SKIPPED_COUNT++))
            continue
        fi

        if ! is_java_process "$PID"; then
            log "WARNING: PID $PID does not appear to be a Java process."

            printf 'Dump %s | PID %s | Status: Not identified as Java process\n' \
                "$dump_number" "$PID" >> "$SUMMARY_FILE"

            ((SKIPPED_COUNT++))
            continue
        fi

        DUMP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        FILE_PREFIX="$OUTPUT_DIR/pid_${PID}_dump_${dump_number}_${DUMP_TIMESTAMP}"

        THREAD_DUMP_FILE="${FILE_PREFIX}_thread_dump.txt"
        TOP_FILE="${FILE_PREFIX}_top_threads.txt"
        PROCESS_FILE="${FILE_PREFIX}_process_details.txt"

        log "Collecting dump $dump_number for PID $PID."

        collect_process_details "$PID" "$PROCESS_FILE"

        TOP_STATUS="SUCCESS"
        if ! collect_top_snapshot "$PID" "$TOP_FILE"; then
            TOP_STATUS="FAILED"
            log "WARNING: top collection failed for PID $PID."
            echo "$(date) | PID $PID | top collection failed" >> "$ERROR_FILE"
        fi

        THREAD_DUMP_STATUS="SUCCESS"
        if collect_thread_dump "$PID" "$THREAD_DUMP_FILE"; then
            ((SUCCESS_COUNT++))
            log "Thread dump completed for PID $PID."
        else
            THREAD_DUMP_STATUS="FAILED"
            ((FAILURE_COUNT++))

            log "ERROR: Thread dump failed for PID $PID."
            echo "$(date) | PID $PID | thread dump failed" >> "$ERROR_FILE"
        fi

        {
            printf 'Dump %s | PID %s | ThreadDump: %s | Top: %s | Process: %s' \
                "$dump_number" \
                "$PID" \
                "$THREAD_DUMP_FILE" \
                "$TOP_FILE" \
                "$PROCESS_FILE"

            printf ' | ThreadDumpStatus: %s | TopStatus: %s\n' \
                "$THREAD_DUMP_STATUS" \
                "$TOP_STATUS"
        } >> "$SUMMARY_FILE"
    done

    # Do not sleep unnecessarily after the final dump cycle.
    if ((dump_number < COUNT)) && [[ "$INTERRUPTED" == false ]]; then
        log "Waiting ${INTERVAL}s before the next dump cycle."
        sleep "$INTERVAL"
    fi
done

# -----------------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------------

{
    echo "========================================"
    echo "Completed At       : $(date)"
    echo "Successful Dumps   : $SUCCESS_COUNT"
    echo "Failed Dumps       : $FAILURE_COUNT"
    echo "Skipped Dumps      : $SKIPPED_COUNT"
    echo "Interrupted        : $INTERRUPTED"
} >> "$SUMMARY_FILE"

log "Thread dump collection completed."
log "Successful: $SUCCESS_COUNT | Failed: $FAILURE_COUNT | Skipped: $SKIPPED_COUNT"
log "Summary: $SUMMARY_FILE"

if ((FAILURE_COUNT > 0)); then
    exit 2
fi

if [[ "$INTERRUPTED" == true ]]; then
    exit 130
fi

exit 0
