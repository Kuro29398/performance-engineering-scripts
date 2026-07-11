# Performance Engineering Scripts

Collection of useful scripts for Performance Engineering, SRE, Production Support and Troubleshooting.

## Available Scripts

# Thread Dump Collector

## multi_pid_threaddump.sh

This script collects multiple thread dumps and CPU snapshots for one or more Java processes.

It uses:

* `jcmd Thread.print -l` when available
* `jstack -l` as a fallback
* `top -H` to capture CPU usage for individual Java threads
* `ps` to capture process CPU, memory and thread details

The script also validates the input, checks whether each PID is running, records failures, and generates a summary file.

## Usage

```bash
./multi_pid_threaddump.sh "PID1 PID2" <dump_count> <interval_seconds>
```

## Example

```bash
./multi_pid_threaddump.sh "1234 5678" 5 10
```

This command:

* Collects thread dumps for PIDs `1234` and `5678`
* Takes `5` dumps for each process
* Waits `10` seconds between each dump cycle

## Make the Script Executable

```bash
chmod +x multi_pid_threaddump.sh
```

## Output

The script creates a timestamped directory:

```text
thread_dumps_<hostname>_<timestamp>/
```

The directory contains:

```text
summary.txt
errors.log
pid_<PID>_dump_<number>_<timestamp>_thread_dump.txt
pid_<PID>_dump_<number>_<timestamp>_top_threads.txt
pid_<PID>_dump_<number>_<timestamp>_process_details.txt
```

## Requirements

The following commands must be available:

```text
bash
ps
top
jcmd or jstack
```

The `timeout` command is optional but recommended.

Run the script using the same operating-system user that owns the Java process, or with sufficient permissions to access the JVM.

## Recommended Usage

For most production troubleshooting:

```bash
./multi_pid_threaddump.sh "1234" 5 10
```

This collects five thread dumps with a ten-second interval, which helps identify repeated blocked, waiting or CPU-intensive threads.


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
