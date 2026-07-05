# Performance Engineering Scripts

Collection of useful scripts for Performance Engineering, SRE, Production Support and Troubleshooting.

## Available Scripts

### Thread Dumps

#### multi_pid_threaddump.sh

This script takes multiple thread dumps for one or more Java processes using `jstack`.

**Usage:**

```bash
./multi_pid_threaddump.sh "1234 5678" 5 1
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
