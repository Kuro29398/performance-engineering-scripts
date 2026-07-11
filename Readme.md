# Performance Engineering Scripts

Collection of useful scripts for Performance Engineering, SRE, Production Support and Troubleshooting.

## Available Scripts

## Thread Dump Collector

## multi_pid_threaddump.sh

Collects repeated thread dumps for one or more Java processes.

The script also captures:

* Per-thread CPU usage using `top -H`
* Process CPU, memory and thread details
* A summary file for each collection

It uses `jcmd` when available and falls back to `jstack`.

## Usage

```bash
./multi_pid_threaddump.sh -p "PID1 PID2" -c <count> -i <interval>
```

### Example

```bash
./multi_pid_threaddump.sh -p "1234 5678" -c 5 -i 10
```

This collects 5 dumps for both PIDs with a 10-second interval.

## Automatically Detect Java PIDs

```bash
./multi_pid_threaddump.sh -a -c 5 -i 10
```

## Compress Output

```bash
./multi_pid_threaddump.sh -p "1234" -c 5 -i 10 -z
```

## Output

The script creates a timestamped directory containing:

* Thread dumps
* CPU snapshots
* Process details
* `summary.txt`

## Requirements

```text
bash
ps
top
jcmd or jstack
```

Make the script executable before running:

```bash
chmod +x multi_pid_threaddump.sh
```

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
