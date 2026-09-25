# PROD vs PERF Config Compare Tool – V5

## Purpose
This tool compares **PROD configuration against PERF** and identifies:

- **Value Changed**
- **Missing in PERF**
- **Added in PERF**
- **Same** when using Full Validation

It supports YAML/config files and also searches inside values such as `JAVA_OPTS`.

## How to Run

1. Extract `PROD_PERF_Config_Compare_Tool_V5.zip`.
2. Open the extracted folder.
3. Double-click **`Start_YAML_Compare_V5.bat`**.
4. Select the **PROD file** under `PROD (Baseline)`.
5. Select the corresponding **PERF file** under `PERF`.
6. Click **Compare**.
7. Use **Delta Only** to see differences or **Full Validation** to see everything.
8. Optionally use Quick Filter or Custom Filter, e.g. `cassandra`, `parallel`, `java`, `memory`.
9. Click any result to see its complete PROD/PERF value.
10. Use **Export CSV** if required.

## Which Files to Upload?

You only need to provide the **two corresponding files** you want to compare:

```text
PROD file → PROD (Baseline)
PERF file → PERF
```

For example:
