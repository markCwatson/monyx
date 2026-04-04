#!/usr/bin/env python3
"""
Download, normalize, and convert public/Crown land boundary data into a
Mapbox-compatible vector tileset (MBTiles).

PROOF-OF-CONCEPT: Nova Scotia only.
- CPCAD (Canadian Protected & Conserved Areas Database) — via ArcGIS REST API
- NS Crown Land (Nova Scotia Open Data via Socrata) — unprotected Crown land

Prerequisites:
    pip install requests          (for HTTP downloads)
    brew install tippecanoe       (for vector tile generation)

Usage:
    # 1. Activate the tools venv (reuse existing or create new)
    source tools/.venv/bin/activate
    pip install -r tools/land_requirements.txt

    # 2. Download raw data (queries CPCAD REST API + NS Crown Land)
    python tools/build_land_tileset.py download

    # 3. Process (normalize + merge into GeoJSON)
    python tools/build_land_tileset.py process

    # 4. Generate vector tiles (requires tippecanoe installed)
    python tools/build_land_tileset.py tiles

    # Or run all steps:
    python tools/build_land_tileset.py all

Output:
    tools/land_data/output/land_overlay.mbtiles  — upload this to Mapbox Studio

After upload:
    1. Go to https://studio.mapbox.com/tilesets/
    2. Click "New tileset" → upload land_overlay.mbtiles
    3. Note the tileset ID (e.g., yourusername.land_overlay)
    4. Add the tileset ID to lib/config.dart as landTilesetId
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

# ─── Paths ──────────────────────────────────────────────────────────────
TOOLS_DIR = Path(__file__).parent
LAND_DIR = TOOLS_DIR / "land_data"
RAW_DIR = LAND_DIR / "raw"
PROCESSED_DIR = LAND_DIR / "processed"
OUTPUT_DIR = LAND_DIR / "output"

# ─── Data sources ───────────────────────────────────────────────────────
# CPCAD: Canadian Protected & Conserved Areas Database — ArcGIS REST API
# Queried by province (LOC field) so we only download what we need.
# https://open.canada.ca/data/en/dataset/6c343726-1e92-451a-876a-76e17d398a1c
CPCAD_REST_URL = (
    "https://maps-cartes.ec.gc.ca/arcgis/rest/services/CWS_SCF/CPCAD/MapServer/0"
)

# LOC coded values for provinces (used in the CPCAD REST query)
CPCAD_LOC_CODES: dict[str, int] = {
    "AB": 1,
    "BC": 2,
    "MB": 3,
    "NB": 4,
    "NL": 5,
    "NT": 6,
    "NS": 7,
    "NU": 8,
    "ON": 9,
    "PE": 10,
    "QC": 11,
    "SK": 12,
    "YT": 13,
}

# Nova Scotia Crown Land — provincial open data (Socrata SODA API)
# https://data.novascotia.ca/Lands-Forests-and-Wildlife/Crown-Land/3nka-59nz
NS_CROWN_URL = "https://data.novascotia.ca/resource/3nka-59nz.geojson?$limit=50000"

# ─── Manager category mapping ──────────────────────────────────────────
# Maps raw designation types to normalized categories for color-coding.
CPCAD_TYPE_MAP: dict[str, str] = {
    # National parks system
    "National Park": "federal_park",
    "National Park Reserve": "federal_park",
    "National Marine Conservation Area": "federal_park",
    "National Marine Conservation Area Reserve": "federal_park",
    "National Wildlife Area": "wildlife_mgmt",
    "Migratory Bird Sanctuary": "wildlife_mgmt",
    "Marine National Wildlife Area": "wildlife_mgmt",
    # Provincial/territorial
    "Provincial Park": "provincial_park",
    "Territorial Park": "provincial_park",
    "Ecological Reserve": "conservation",
    "Provincial Wildlife Management Area": "wildlife_mgmt",
    "Provincial Nature Reserve": "conservation",
    "Wilderness Area": "conservation",
    "Game Sanctuary": "wildlife_mgmt",
    "Nature Reserve": "conservation",
    "Wildlife Management Area": "wildlife_mgmt",
    "Protected Wilderness Area": "conservation",
    "Provincial Wilderness Area": "conservation",
    "Wildlife Refuge": "wildlife_mgmt",
}


def ensure_dirs() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ─── Step 1: Download ──────────────────────────────────────────────────
def _query_cpcad_geojson(
    requests_mod: object,
    province_code: str,
    biome: str = "T",
) -> dict:
    """Query the CPCAD ArcGIS REST service for a province, returning GeoJSON.

    Handles pagination automatically when the server has a maxRecordCount limit.
    """
    import requests  # type: ignore[attr-defined]

    loc = CPCAD_LOC_CODES.get(province_code)
    if loc is None:
        sys.exit(f"Unknown province code: {province_code}")

    where = f"LOC={loc} AND BIOME='{biome}'"
    all_features: list[dict] = []
    offset = 0
    page_size = 1000  # server returns HTML errors above ~1000

    while True:
        qs = (
            f"where={requests.utils.quote(where)}"
            f"&outFields=*&f=geojson&outSR=4326"
            f"&resultOffset={offset}&resultRecordCount={page_size}"
        )
        url = f"{CPCAD_REST_URL}/query?{qs}"
        print(f"    Querying offset={offset}...")
        resp = requests.get(
            url,
            headers={"User-Agent": "Mozilla/5.0 (Atlix Hunt land-overlay pipeline)"},
            timeout=120,
        )
        resp.raise_for_status()
        if not resp.text.strip().startswith("{"):
            print(f"    Unexpected response (first 500 chars):\n{resp.text[:500]}")
            sys.exit("CPCAD REST API did not return JSON. The service may be down.")
        data = resp.json()

        features = data.get("features", [])
        all_features.extend(features)
        print(f"    Got {len(features)} features (total so far: {len(all_features)})")

        # ArcGIS returns exceededTransferLimit=true when there are more pages
        if data.get("exceededTransferLimit") or (
            "properties" in data and data["properties"].get("exceededTransferLimit")
        ):
            offset += len(features)
        else:
            break

    return {"type": "FeatureCollection", "features": all_features}


def download() -> None:
    """Download raw data files."""
    ensure_dirs()

    try:
        import requests  # noqa: F811
    except ImportError:
        sys.exit("Missing 'requests'. Run: pip install -r tools/land_requirements.txt")

    # CPCAD — query Nova Scotia protected areas from REST API
    cpcad_raw = RAW_DIR / "cpcad_ns_raw.geojson"
    if not cpcad_raw.exists():
        print("Querying CPCAD REST API for Nova Scotia protected areas...")
        print(f"  Service: {CPCAD_REST_URL}")
        data = _query_cpcad_geojson(requests, "NS")
        cpcad_raw.write_text(json.dumps(data), encoding="utf-8")
        n = len(data["features"])
        size_kb = cpcad_raw.stat().st_size >> 10
        print(f"  Saved: {cpcad_raw} ({n} features, {size_kb} KB)")
    else:
        print(f"CPCAD NS already downloaded: {cpcad_raw}")

    # Nova Scotia Crown Land — Socrata open data
    ns_crown = RAW_DIR / "ns_crown_land.geojson"
    if not ns_crown.exists():
        print("Downloading Nova Scotia Crown Land...")
        print(f"  URL: {NS_CROWN_URL}")
        resp = requests.get(
            NS_CROWN_URL,
            headers={"User-Agent": "Mozilla/5.0 (Atlix Hunt land-overlay pipeline)"},
            timeout=120,
        )
        resp.raise_for_status()
        ns_crown.write_text(resp.text, encoding="utf-8")
        print(f"  Saved: {ns_crown} ({ns_crown.stat().st_size >> 10} KB)")
    else:
        print(f"NS Crown Land already downloaded: {ns_crown}")

    print("\nDownload complete.")


# ─── Step 2: Process ───────────────────────────────────────────────────
def _map_cpcad_type(designation: str | None) -> str:
    """Map a CPCAD designation type to our normalized manager category."""
    if not designation:
        return "conservation"
    for key, value in CPCAD_TYPE_MAP.items():
        if key.lower() in designation.lower():
            return value
    return "conservation"  # default


def process() -> None:
    """Normalize both datasets and merge into a single GeoJSON."""
    ensure_dirs()

    cpcad_raw = RAW_DIR / "cpcad_ns_raw.geojson"
    ns_crown = RAW_DIR / "ns_crown_land.geojson"

    if not cpcad_raw.exists():
        sys.exit(
            f"Missing {cpcad_raw}. Run: python tools/build_land_tileset.py download"
        )
    if not ns_crown.exists():
        sys.exit(
            f"Missing {ns_crown}. Run: python tools/build_land_tileset.py download"
        )

    # ── 2a. Normalize CPCAD NS features ─────────────────────────────
    print("Normalizing CPCAD NS features...")
    cpcad_ns_norm = PROCESSED_DIR / "cpcad_ns_normalized.geojson"
    with open(cpcad_raw, "r", encoding="utf-8") as f:
        cpcad_data = json.load(f)

    sample_features = cpcad_data.get("features", [])[:3]
    if sample_features:
        print(
            f"  Sample properties: {list(sample_features[0].get('properties', {}).keys())}"
        )

    normalized_features = []
    for feat in cpcad_data.get("features", []):
        props = feat.get("properties", {})
        # REST API field names: TYPE_E, MGMT_E, NAME_E, OWNER_E, etc.
        mgmt_type = props.get("TYPE_E") or props.get("MGMT_E") or ""
        name = props.get("NAME_E") or props.get("NAME_F") or "Unknown"
        manager_name = props.get("MGMT_E") or props.get("OWNER_E") or "Unknown"

        category = _map_cpcad_type(mgmt_type)

        normalized_features.append(
            {
                "type": "Feature",
                "geometry": feat["geometry"],
                "properties": {
                    "country": "CA",
                    "manager": category,
                    "manager_name": manager_name,
                    "name": name,
                    "province_state": "NS",
                    "source": "cpcad",
                },
            }
        )

    with open(cpcad_ns_norm, "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": normalized_features}, f)
    print(f"  {len(normalized_features)} CPCAD features normalized → {cpcad_ns_norm}")

    # ── 2c. Normalize NS Crown Land ──────────────────────────────────
    print("\nNormalizing Nova Scotia Crown Land features...")
    ns_crown_norm = PROCESSED_DIR / "ns_crown_normalized.geojson"
    with open(ns_crown, "r", encoding="utf-8") as f:
        ns_data = json.load(f)

    crown_features = []
    for feat in ns_data.get("features", []):
        props = feat.get("properties", {})
        # Crown land type — the NS dataset uses various field names
        land_type = (
            props.get("LAND_TYPE", "")
            or props.get("land_type", "")
            or props.get("TYPE", "")
            or ""
        )
        name = (
            props.get("NAME", "")
            or props.get("name", "")
            or props.get("PARCEL_ID", "")
            or "Crown Land"
        )

        crown_features.append(
            {
                "type": "Feature",
                "geometry": feat["geometry"],
                "properties": {
                    "country": "CA",
                    "manager": "crown_land",
                    "manager_name": "Nova Scotia DNR",
                    "name": name,
                    "province_state": "NS",
                    "source": "ns_open_data",
                },
            }
        )

    with open(ns_crown_norm, "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": crown_features}, f)
    print(f"  {len(crown_features)} Crown Land features normalized → {ns_crown_norm}")

    # ── 2d. Merge into single GeoJSON ────────────────────────────────
    print("\nMerging all features...")
    merged = PROCESSED_DIR / "merged_land.geojson"
    all_features = normalized_features + crown_features
    with open(merged, "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": all_features}, f)
    print(f"  Total: {len(all_features)} features → {merged}")
    print("\nProcess complete.")


# ─── Step 3: Generate tiles ────────────────────────────────────────────
def tiles() -> None:
    """Run tippecanoe to generate vector MBTiles from the merged GeoJSON."""
    ensure_dirs()

    merged = PROCESSED_DIR / "merged_land.geojson"
    if not merged.exists():
        sys.exit(f"Missing {merged}. Run: python tools/build_land_tileset.py process")

    output = OUTPUT_DIR / "land_overlay.mbtiles"

    # Check tippecanoe is installed
    try:
        subprocess.run(["tippecanoe", "--version"], capture_output=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        sys.exit(
            "tippecanoe is required but not found.\n"
            "Install: brew install tippecanoe  (macOS)"
        )

    cmd = [
        "tippecanoe",
        "-o",
        str(output),
        "-Z",
        "4",  # min zoom
        "-z",
        "14",  # max zoom
        "-l",
        "public_land",  # layer name (referenced in Flutter code)
        "--drop-densest-as-needed",
        "--extend-zooms-if-still-dropping",
        "--force",  # overwrite existing output
        "-n",
        "Land Overlay (NS POC)",  # tileset name
        "-A",
        "CPCAD (ECCC) + NS Open Data",  # attribution
        str(merged),
    ]

    print("Generating vector tiles with tippecanoe...")
    print(f"  $ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"STDERR: {result.stderr}")
        sys.exit("tippecanoe failed")
    print(result.stderr)  # tippecanoe prints stats to stderr

    size_mb = output.stat().st_size / (1 << 20)
    print(f"\nOutput: {output} ({size_mb:.1f} MB)")
    print(
        "\nNext steps:\n"
        "  1. Upload to Mapbox Studio: https://studio.mapbox.com/tilesets/\n"
        "  2. Click 'New tileset' → upload land_overlay.mbtiles\n"
        "  3. Copy the tileset ID (e.g., yourusername.land_overlay)\n"
        "  4. Set it in lib/config.dart as landTilesetId\n"
    )


# ─── CLI ────────────────────────────────────────────────────────────────
def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in ("download", "process", "tiles", "all"):
        print(
            "Usage: python tools/build_land_tileset.py <command>\n"
            "\n"
            "Commands:\n"
            "  download  — Download raw government datasets\n"
            "  process   — Normalize and merge into unified GeoJSON\n"
            "  tiles     — Generate MBTiles with tippecanoe\n"
            "  all       — Run all steps in order"
        )
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd in ("download", "all"):
        download()
    if cmd in ("process", "all"):
        process()
    if cmd in ("tiles", "all"):
        tiles()


if __name__ == "__main__":
    main()
