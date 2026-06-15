# Performance Engineering Scripts

Collection of useful scripts for Performance Engineering, SRE, Production Support and Troubleshooting.

## Available Scripts

### Thread Dumps

#### multi_pid_threaddump.sh

This script takes multiple thread dumps for one or more Java processes using jstack.

Usage:

```bash
./multi_pid_threaddump.sh "1234 5678" 5 1
