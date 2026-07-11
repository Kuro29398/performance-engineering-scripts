# Performance Engineering Scripts

Collection of useful scripts for Performance Engineering, SRE, Production Support and Troubleshooting.

## Available Scripts

# Thread Dump Collector

## multi_pid_threaddump.sh

Collects multiple thread dumps for one or more Java processes.

The script:

* Collects thread dumps using **jcmd** (or **jstack** if `jcmd` is unavailable).
* Captures per-thread CPU usage using `top -H`.
* Collects process details (CPU, memory and thread count).
* Generates a timestamped output directory with all dumps and a summary report.
* Validates inputs and skips invalid or unavailable PIDs.

## Usage

```bash
./multi_pid_threaddump.sh "PID1 PID2" <dump_count> <interval_seconds>
```

### Example

```bash
./multi_pid_threaddump.sh "1234 5678" 5 10
```

This collects **5 thread dumps** for each PID with a **10-second interval** between dump cycles.

## Output

The script creates a timestamped folder containing:

* Thread dump files
* Thread CPU snapshots (`top -H`)
* Process details
* `summary.txt`
* `errors.log` (if any failures occur)


---

### Heap Dumps

#### heapdump.sh

This script captures a Java heap dump for a specified Java process using `jcmd`.

**Usage:**

```bash
./heapdump.sh <PID>
```

**Example:**

```bash
./heapdump.sh 12345
```

**Custom Output Directory:**

```bash
./heapdump.sh 12345 /tmp
```

The heap dump will be generated as:

```text
heapdump_<PID>_<TIMESTAMP>.hprof
```
