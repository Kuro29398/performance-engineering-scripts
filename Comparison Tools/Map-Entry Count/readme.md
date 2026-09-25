# Map Comparison Tool

A Windows-based Streamlit application that reads map names and entry counts from screenshots using OCR, compares two regions, and calculates the difference.

## Features

- Upload screenshots for two regions
- Paste screenshots directly with `Ctrl+V`
- Use custom region names, such as `EUC` and `EUW`
- Extract map names and entry counts using Tesseract OCR
- Calculate:

```text
Delta = Base region entries - Other region entries
```

- Show summary cards:
  - Total Maps
  - Exact Matches
  - Differences
  - Need Review
- Flag unclear OCR results
- Flag maps missing from either region
- Copy data from the final table
- Download results as CSV
- Clear results and start a new comparison

## Requirements

- Windows
- Python 3.13 or newer
- Tesseract OCR
- Git Bash or PowerShell

## Installation

### 1. Create and activate the virtual environment

From Git Bash:

```bash
python -m venv .venv
source .venv/Scripts/activate
```

### 2. Install Python packages

```bash
python -m pip install --upgrade pip
python -m pip install streamlit pytesseract pillow pandas st-img-pastebutton
```

### 3. Install Tesseract OCR

Install Tesseract OCR for Windows.

The application expects Tesseract at:

```text
C:\Users\1043568\AppData\Local\Tesseract-OCR\tesseract.exe
```

If Tesseract is installed somewhere else, update `TESSERACT_PATH` in `app.py`.

Test the installation:

```bash
"/c/Users/1043568/AppData/Local/Tesseract-OCR/tesseract.exe" --version
```

## Run the application

Activate the virtual environment:

```bash
source .venv/Scripts/activate
```

Start the application:

```bash
python -m streamlit run app.py
```

Open the application in a browser:

```text
http://localhost:8501
```

## How to use

1. Enter the name of the base region.
2. Enter the name of the other region.
3. Upload or paste screenshots for the base region.
4. Upload or paste screenshots for the other region.
5. Click **Read screenshots and compare**.
6. Review the final comparison table.
7. Copy the table or download it as CSV.

## Screenshot requirements

For better OCR accuracy:

- Keep the `Name` and `Entries` columns visible.
- Use clear, high-resolution screenshots.
- Keep the same zoom level for both regions.
- Do not cut off map names or entry counts.
- Use multiple screenshots if the table is longer than one screen.
- Include overlapping rows when using multiple screenshots.

## Result columns

| Column | Description |
|---|---|
| Map name | Name of the map |
| Base region entries | Entry count from the base region |
| Other region entries | Entry count from the other region |
| Delta | Base entries minus other entries |
| Status | OCR or missing-data warning |

Example:

| Map name | EUC entries | EUW entries | Delta | Status |
|---|---:|---:|---:|---|
| `wsi_PRODUCT` | 120 | 100 | 20 | ✅ Read clearly |

## Missing or unclear data

The application does not treat missing data as zero.

If a map is not detected in one region, the result is shown as blank and the row is flagged:

```text
⚠️ Not detected in EUW
```

If OCR confidence is low, the row is flagged:

```text
⚠️ Check EUC OCR
```

Always review rows marked **Need Review** before using the final results.

## Stop the application

In the terminal running Streamlit, press:

```text
Ctrl+C
```

Leave the virtual environment:

```bash
deactivate
```

## Recommended project structure

```text
map-comparison-tool/
├── app.py
├── README.md
├── .gitignore
└── .venv/
```

The `.venv` folder should not be committed to GitHub.

## License

Add your project license here.
