import base64
import io
import re
from collections import defaultdict

import pandas as pd
import pytesseract
import streamlit as st

from PIL import Image, ImageEnhance, ImageOps
from pytesseract import Output
from st_img_pastebutton import paste


# ============================================================
# CONFIGURATION
# ============================================================

TESSERACT_PATH = (
    r"C:\Users\1043568\AppData\Local\Tesseract-OCR\tesseract.exe"
)

pytesseract.pytesseract.tesseract_cmd = TESSERACT_PATH

RESULT_COLUMNS = [
    "Map name",
    "Base Region entries",
    "Other Region entries",
    "Delta",
    "Status",
]


# ============================================================
# PAGE CONFIGURATION
# ============================================================

st.set_page_config(
    page_title="Map Comparison Tool",
    page_icon="🗺️",
    layout="wide",
)

st.title("🗺️ Map Region Comparison Tool")

st.write(
    "Upload or paste screenshots from two regions. "
    "Delta is calculated as Base region entries minus Other region entries."
)


# ============================================================
# SESSION STATE
# ============================================================

if "result_df" not in st.session_state:
    st.session_state.result_df = None

if "base_pasted_image" not in st.session_state:
    st.session_state.base_pasted_image = None

if "other_pasted_image" not in st.session_state:
    st.session_state.other_pasted_image = None

if "upload_version" not in st.session_state:
    st.session_state.upload_version = 0


def clear_application():
    st.session_state.result_df = None
    st.session_state.base_pasted_image = None
    st.session_state.other_pasted_image = None
    st.session_state.upload_version += 1


# ============================================================
# IMAGE FUNCTIONS
# ============================================================

def data_uri_to_image(data_uri):
    """Convert pasted image data into a PIL image."""
    if not data_uri:
        return None

    try:
        if "," in data_uri:
            _, encoded_data = data_uri.split(",", 1)
        else:
            encoded_data = data_uri

        image_bytes = base64.b64decode(encoded_data)

        return Image.open(
            io.BytesIO(image_bytes)
        ).convert("RGB")

    except Exception:
        return None


def uploaded_file_to_image(uploaded_file):
    """Convert an uploaded file to a PIL image."""
    return Image.open(uploaded_file).convert("RGB")


def preprocess_image(image):
    """Improve the screenshot before OCR."""
    image = image.convert("RGB")
    image = ImageOps.grayscale(image)

    image = image.resize(
        (
            image.width * 2,
            image.height * 2,
        )
    )

    image = ImageEnhance.Contrast(image).enhance(1.8)

    return image


def clean_number(text):
    """Convert OCR text such as 31,234,483 into an integer."""
    if text is None:
        return None

    text = str(text).strip()

    # Ignore text that contains no digit.
    if not re.search(r"\d", text):
        return None

    digits = re.sub(r"[^\d]", "", text)

    if not digits:
        return None

    try:
        return int(digits)
    except ValueError:
        return None


def normalize_map_name(name):
    """Normalize a map name only for matching between regions."""
    name = str(name).strip().lower()
    return re.sub(r"\s+", "", name)


# ============================================================
# OCR FUNCTIONS
# ============================================================

def find_column_positions(ocr_data, image_width):
    """
    Find the Name and Entries column positions.
    Uses fallback positions if OCR cannot read the headers.
    """
    name_x = None
    entries_x = None

    for index, text in enumerate(ocr_data["text"]):
        word = text.strip().lower()

        if not word:
            continue

        x_position = int(ocr_data["left"][index])

        if word == "name":
            name_x = x_position

        if word == "entries":
            entries_x = x_position

    if name_x is None:
        name_x = int(image_width * 0.05)

    if entries_x is None:
        entries_x = int(image_width * 0.70)

    return name_x, entries_x


def extract_rows_from_image(image, source_name):
    """
    Extract map names and entry counts from one screenshot.
    Rows with low OCR confidence are retained and flagged.
    """
    processed_image = preprocess_image(image)

    ocr_data = pytesseract.image_to_data(
        processed_image,
        output_type=Output.DICT,
        config="--psm 6",
    )

    name_x, entries_x = find_column_positions(
        ocr_data,
        processed_image.width,
    )

    separator_x = int((name_x + entries_x) / 2)

    lines = defaultdict(list)

    for index, text in enumerate(ocr_data["text"]):
        text = text.strip()

        if not text:
            continue

        try:
            confidence = float(ocr_data["conf"][index])
        except (TypeError, ValueError):
            confidence = 0

        # Ignore extremely unreliable OCR words.
        if confidence < 20:
            continue

        line_key = (
            ocr_data["block_num"][index],
            ocr_data["par_num"][index],
            ocr_data["line_num"][index],
        )

        lines[line_key].append(
            {
                "text": text,
                "left": int(ocr_data["left"][index]),
                "confidence": confidence,
            }
        )

    extracted_rows = []

    for words in lines.values():
        words = sorted(
            words,
            key=lambda item: item["left"],
        )

        full_line = " ".join(
            word["text"]
            for word in words
        )

        lower_line = full_line.lower()

        ignored_terms = [
            "persistence",
            "indexes",
            "memory",
            "backup",
            "maps",
            "search",
            "default",
            "show",
            "system",
            "healthcheck",
            "management",
            "center",
            "view",
        ]

        # Ignore headers and page controls.
        if (
            any(term in lower_line for term in ignored_terms)
            and "wsi_" not in lower_line
        ):
            continue

        # Read the map name from the left side.
        name_words = []

        for word in words:
            if word["left"] < separator_x:
                if not re.search(r"\d{2,}", word["text"]):
                    name_words.append(word)

        map_name = "".join(
            word["text"]
            for word in name_words
        ).strip()

        # Your maps normally contain wsi_.
        if not map_name:
            continue

        if "wsi_" not in map_name.lower():
            continue

        # Find numbers in the row.
        numeric_candidates = []

        for word in words:
            number = clean_number(word["text"])

            if number is not None:
                numeric_candidates.append(
                    {
                        "number": number,
                        "left": word["left"],
                        "confidence": word["confidence"],
                    }
                )

        if not numeric_candidates:
            continue

        # Choose the number closest to the Entries column.
        entry_value = min(
            numeric_candidates,
            key=lambda item: abs(
                item["left"] - entries_x
            ),
        )

        # Prevent selecting Entry Memory or Backup Memory.
        if abs(entry_value["left"] - entries_x) > 260:
            continue

        name_confidences = [
            word["confidence"]
            for word in name_words
        ]

        if name_confidences:
            name_confidence = (
                sum(name_confidences)
                / len(name_confidences)
            )
        else:
            name_confidence = 0

        row_confidence = min(
            name_confidence,
            entry_value["confidence"],
        )

        if row_confidence < 55:
            ocr_status = "⚠️ Review OCR"
        else:
            ocr_status = "✅ Read clearly"

        extracted_rows.append(
            {
                "Map name": map_name,
                "Entries": entry_value["number"],
                "OCR status": ocr_status,
                "Source": source_name,
            }
        )

    return extracted_rows


def extract_region_data(image_sources):
    """
    Extract rows from all images for one region.
    If screenshots overlap, the first occurrence is kept.
    """
    region_data = {}
    row_order = 0

    for source_name, image in image_sources:
        rows = extract_rows_from_image(
            image,
            source_name,
        )

        for row in rows:
            map_key = normalize_map_name(
                row["Map name"]
            )

            if map_key not in region_data:
                row_order += 1
                row["_order"] = row_order
                region_data[map_key] = row

    return region_data


# ============================================================
# SOURCE FUNCTIONS
# ============================================================

def get_uploaded_sources(uploaded_files, region_label):
    sources = []

    if not uploaded_files:
        return sources

    for uploaded_file in uploaded_files:
        try:
            image = uploaded_file_to_image(
                uploaded_file
            )

            sources.append(
                (
                    f"{region_label}: {uploaded_file.name}",
                    image,
                )
            )

        except Exception as error:
            st.warning(
                f"Could not open {uploaded_file.name}: {error}"
            )

    return sources


def get_pasted_source(data_uri, region_label):
    image = data_uri_to_image(data_uri)

    if image is None:
        return []

    return [
        (
            f"{region_label}: pasted screenshot",
            image,
        )
    ]


# ============================================================
# SIDEBAR
# ============================================================

st.sidebar.header("Region names")

base_region_name = st.sidebar.text_input(
    "Base region name",
    value="Base Region",
    max_chars=40,
).strip()

other_region_name = st.sidebar.text_input(
    "Other region name",
    value="Other Region",
    max_chars=40,
).strip()

if not base_region_name:
    base_region_name = "Base Region"

if not other_region_name:
    other_region_name = "Other Region"

same_region_names = (
    base_region_name.lower()
    == other_region_name.lower()
)

if same_region_names:
    st.sidebar.error(
        "The two region names must be different."
    )

st.sidebar.divider()

st.sidebar.button(
    "🔄 Clear / start new comparison",
    on_click=clear_application,
    use_container_width=True,
)


# ============================================================
# UPLOAD AND PASTE
# ============================================================

st.subheader("1. Upload or paste screenshots")

base_column, other_column = st.columns(2)

with base_column:
    st.markdown(
        f"### Base region: {base_region_name}"
    )

    base_files = st.file_uploader(
        "Choose or drag base screenshots",
        type=["png", "jpg", "jpeg"],
        accept_multiple_files=True,
        key=(
            f"base_uploader_"
            f"{st.session_state.upload_version}"
        ),
    )

    st.caption(
        "Or copy a screenshot, click the button, "
        "then paste with Ctrl+V."
    )

    base_paste_data = paste(
        label="📋 Paste base screenshot",
        key=(
            f"base_paste_"
            f"{st.session_state.upload_version}"
        ),
    )

    if base_paste_data:
        st.session_state.base_pasted_image = (
            base_paste_data
        )

    if st.session_state.base_pasted_image:
        pasted_image = data_uri_to_image(
            st.session_state.base_pasted_image
        )

        if pasted_image:
            st.success(
                "Base screenshot pasted successfully."
            )

            st.image(
                pasted_image,
                caption="Pasted base screenshot",
                use_container_width=True,
            )

with other_column:
    st.markdown(
        f"### Other region: {other_region_name}"
    )

    other_files = st.file_uploader(
        "Choose or drag other-region screenshots",
        type=["png", "jpg", "jpeg"],
        accept_multiple_files=True,
        key=(
            f"other_uploader_"
            f"{st.session_state.upload_version}"
        ),
    )

    st.caption(
        "Or copy a screenshot, click the button, "
        "then paste with Ctrl+V."
    )

    other_paste_data = paste(
        label="📋 Paste other-region screenshot",
        key=(
            f"other_paste_"
            f"{st.session_state.upload_version}"
        ),
    )

    if other_paste_data:
        st.session_state.other_pasted_image = (
            other_paste_data
        )

    if st.session_state.other_pasted_image:
        pasted_image = data_uri_to_image(
            st.session_state.other_pasted_image
        )

        if pasted_image:
            st.success(
                "Other-region screenshot pasted successfully."
            )

            st.image(
                pasted_image,
                caption="Pasted other-region screenshot",
                use_container_width=True,
            )


# ============================================================
# BUILD SOURCE LISTS
# ============================================================

base_sources = get_uploaded_sources(
    base_files,
    base_region_name,
)

base_sources += get_pasted_source(
    st.session_state.base_pasted_image,
    base_region_name,
)

other_sources = get_uploaded_sources(
    other_files,
    other_region_name,
)

other_sources += get_pasted_source(
    st.session_state.other_pasted_image,
    other_region_name,
)

has_base_images = len(base_sources) > 0
has_other_images = len(other_sources) > 0

run_disabled = (
    not has_base_images
    or not has_other_images
    or same_region_names
)


# ============================================================
# RUN COMPARISON
# ============================================================

run_clicked = st.button(
    "Read screenshots and compare",
    type="primary",
    disabled=run_disabled,
)

if run_clicked:
    with st.spinner("Reading screenshots using OCR..."):
        base_data = extract_region_data(
            base_sources
        )

        other_data = extract_region_data(
            other_sources
        )

    base_keys = sorted(
        base_data.keys(),
        key=lambda key: base_data[key]["_order"],
    )

    other_only_keys = [
        key
        for key in sorted(
            other_data.keys(),
            key=lambda key: other_data[key]["_order"],
        )
        if key not in base_data
    ]

    comparison_rows = []

    for map_key in base_keys + other_only_keys:
        base_row = base_data.get(map_key)
        other_row = other_data.get(map_key)

        map_name = (
            base_row["Map name"]
            if base_row
            else other_row["Map name"]
        )

        base_entries = (
            base_row["Entries"]
            if base_row
            else None
        )

        other_entries = (
            other_row["Entries"]
            if other_row
            else None
        )

        status_messages = []

        if base_row is None:
            status_messages.append(
                f"Not detected in {base_region_name}"
            )

        if other_row is None:
            status_messages.append(
                f"Not detected in {other_region_name}"
            )

        if (
            base_row
            and "Review" in base_row["OCR status"]
        ):
            status_messages.append(
                f"Check {base_region_name} OCR"
            )

        if (
            other_row
            and "Review" in other_row["OCR status"]
        ):
            status_messages.append(
                f"Check {other_region_name} OCR"
            )

        if status_messages:
            status = "⚠️ " + "; ".join(
                status_messages
            )
        else:
            status = "✅ Read clearly"

        if (
            base_entries is not None
            and other_entries is not None
        ):
            delta = base_entries - other_entries
        else:
            delta = None

        comparison_rows.append(
            {
                "Map name": map_name,
                f"{base_region_name} entries": base_entries,
                f"{other_region_name} entries": other_entries,
                "Delta": delta,
                "Status": status,
            }
        )

    # Important: always create the DataFrame with all expected columns.
    # This prevents KeyError when OCR finds no maps.
    if comparison_rows:
        st.session_state.result_df = pd.DataFrame(
            comparison_rows,
            columns=[
                "Map name",
                f"{base_region_name} entries",
                f"{other_region_name} entries",
                "Delta",
                "Status",
            ],
        )
    else:
        st.session_state.result_df = None

        st.error(
            "No maps were detected in the screenshots. "
            "Make sure the map names and Entries column are visible, "
            "then try again."
        )


# ============================================================
# FINAL COMPARISON
# ============================================================

if st.session_state.result_df is not None:
    final_df = st.session_state.result_df.copy()

    # Safety check before accessing columns.
    required_columns = [
        "Map name",
        f"{base_region_name} entries",
        f"{other_region_name} entries",
        "Delta",
        "Status",
    ]

    missing_columns = [
        column
        for column in required_columns
        if column not in final_df.columns
    ]

    if missing_columns:
        st.error(
            "The comparison table is missing required columns: "
            + ", ".join(missing_columns)
        )
        st.stop()

    st.subheader("2. Final comparison")

    base_column = f"{base_region_name} entries"
    other_column = f"{other_region_name} entries"

    needs_review_mask = (
        final_df["Status"]
        .astype(str)
        .str.startswith("⚠️")
    )

    both_values_available = (
        final_df[base_column].notna()
        & final_df[other_column].notna()
    )

    exact_match_mask = (
        both_values_available
        & ~needs_review_mask
        & (final_df["Delta"] == 0)
    )

    difference_mask = (
        both_values_available
        & ~needs_review_mask
        & (final_df["Delta"] != 0)
    )

    total_maps = len(final_df)
    exact_matches = int(exact_match_mask.sum())
    differences = int(difference_mask.sum())
    need_review = int(needs_review_mask.sum())

    # Summary cards.
    card1, card2, card3, card4 = st.columns(4)

    with card1:
        st.metric("Total Maps", total_maps)

    with card2:
        st.metric("Exact Matches", exact_matches)

    with card3:
        st.metric("Differences", differences)

    with card4:
        st.metric("Need Review", need_review)

    st.caption(
        "Click a column heading to sort. "
        "Select cells in the table and press Ctrl+C to copy."
    )

    st.dataframe(
        final_df,
        use_container_width=True,
        hide_index=True,
        height=650,
    )

    csv_data = final_df.to_csv(
        index=False
    ).encode("utf-8")

    st.download_button(
        label="⬇️ Download CSV",
        data=csv_data,
        file_name="map_comparison.csv",
        mime="text/csv",
    )

    if need_review > 0:
        st.warning(
            f"{need_review} row(s) need review. "
            "Check the Status column before using the results."
        )
    else:
        st.success(
            "All detected maps were read clearly "
            "and found in both regions."
        )

else:
    st.info(
        "Upload or paste at least one screenshot "
        "for each region."
    )


st.divider()

st.caption(
    "Delta = Base region entries - Other region entries. "
    "Missing values remain blank and are not treated as zero."
)