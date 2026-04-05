# Public / Crown Land Overlay

Colour-coded map overlay showing public lands, Crown lands, parks, and wildlife management areas. POC scope is Nova Scotia only; the architecture supports expansion to all Canadian provinces and US states.

## How it works

1. Tap the **layers button** on the map sidebar (Pro only).
2. Semi-transparent polygons appear on the map, colour-coded by land type.
3. Long-press (or tap when already on) to open the **filter sheet** — toggle categories on/off with per-agency checkboxes.
4. Tap "Turn Off Overlay" to remove all layers.

## Colour scheme

| Category          | Colour     | Examples                                              |
| ----------------- | ---------- | ----------------------------------------------------- |
| `federal_park`    | Brown      | National Parks, National Marine Conservation          |
| `provincial_park` | Dark green | Provincial Parks, Territorial Parks                   |
| `crown_land`      | Yellow     | Unprotected Crown Land (Nova Scotia DNR)              |
| `wildlife_mgmt`   | Olive      | Wildlife Management Areas, Migratory Bird Sanctuaries |
| `conservation`    | Teal       | Ecological Reserves, Nature Reserves, Wilderness      |
| `military`        | Red        | Military / Restricted areas                           |

Future US categories (`blm`, `usfs`, `nps`, `state_park`) are pre-wired in the colour palette.

## Data pipeline

The tileset is built offline from government open data using `tools/build_land_tileset.py`. Three steps:

```
download → process → tiles
```

### Prerequisites

```bash
brew install tippecanoe                          # Vector tile generation
source tools/.venv/bin/activate
pip install -r tools/land_requirements.txt       # Just `requests`
```

### Usage

```bash
# Run all three steps in order:
python tools/build_land_tileset.py all

# Or run individually:
python tools/build_land_tileset.py download      # Query APIs → raw GeoJSON
python tools/build_land_tileset.py process       # Normalize → merged GeoJSON
python tools/build_land_tileset.py tiles         # tippecanoe → MBTiles
```

### Step 1: Download

Queries two data sources and saves raw GeoJSON to `tools/land_data/raw/`:

| Source                                                    | API              | File                    | Notes                                                             |
| --------------------------------------------------------- | ---------------- | ----------------------- | ----------------------------------------------------------------- |
| **CPCAD** (Canadian Protected & Conserved Areas Database) | ArcGIS REST API  | `cpcad_ns_raw.geojson`  | Paginated queries (1000 features/page), filtered by province code |
| **NS Crown Land** (Nova Scotia Open Data)                 | Socrata SODA API | `ns_crown_land.geojson` | Single bulk download (up to 50,000 features)                      |

CPCAD is a federal dataset covering all protected areas in Canada. The pipeline filters by province using the `LOC` field (NS = code 7). Province codes for all 13 provinces/territories are defined in the script for future expansion.

### Step 2: Process

Normalizes both datasets into a common schema and merges into `tools/land_data/processed/merged_land.geojson`:

```json
{
  "country": "CA",
  "manager": "crown_land",
  "manager_name": "Nova Scotia DNR",
  "name": "...",
  "province_state": "NS",
  "source": "ns_open_data"
}
```

CPCAD designation types (e.g. "National Park", "Ecological Reserve", "Game Sanctuary") are mapped to normalized `manager` categories using a lookup table. The `manager` field drives colour-coding in the app.

### Step 3: Tiles

Runs tippecanoe to generate a vector tileset:

```bash
tippecanoe -o land_overlay.mbtiles \
  -Z 4 -z 14 \
  -l public_land \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --force \
  merged_land.geojson
```

- Zoom range 4–14 (country level down to neighbourhood)
- Layer name `public_land` (referenced in Flutter code)
- Drops dense features at low zooms to keep tile sizes manageable

Output: `tools/land_data/output/land_overlay.mbtiles`

### After generating tiles

1. Go to [Mapbox Studio Tilesets](https://studio.mapbox.com/tilesets/)
2. Click **New tileset** → upload `land_overlay.mbtiles`
3. Copy the tileset ID (e.g., `yourusername.land_overlay`)
4. Add to `.env`: `LAND_TILESET_ID=yourusername.land_overlay`

## Flutter implementation

The overlay is implemented as a Mapbox `VectorSource` + `FillLayer` + `LineLayer`, driven by the tileset ID from `AppConfig.landTilesetId`.

### Rendering

- **VectorSource** points to `mapbox://{tilesetId}`
- **FillLayer** with 30% opacity for semi-transparent polygon fills
- **LineLayer** with 70% opacity, 1.5px width for boundary lines
- **Data-driven colour** via a Mapbox `match` expression on the `manager` property — the typed Flutter API doesn't support expressions directly, so colours are applied via `setStyleLayerProperty` with a raw match expression array

### Filtering

The filter bottom sheet uses Mapbox GL `filter` expressions:

```
["in", ["get", "manager"], ["literal", ["crown_land", "federal_park", ...]]]
```

Applied to both fill and line layers simultaneously via `setStyleLayerProperty`.

### Offline support

When the user downloads an offline region (via the Offline Regions screen), the land overlay tileset is included alongside the base map styles. This means the overlay works fully offline in downloaded areas.

## Free vs Pro

| Capability                       | Free | Pro |
| -------------------------------- | ---- | --- |
| Land overlay toggle              | —    | ✅  |
| Per-category filtering           | —    | ✅  |
| Offline download with land tiles | —    | ✅  |

## Expanding to other provinces / states

To add a new province:

1. **CPCAD**: Add the province code to the download query (codes are already defined for all 13 provinces/territories in `CPCAD_LOC_CODES`)
2. **Provincial Crown Land**: Find the province's open data portal and add a download step (similar to the NS Socrata query)
3. **Normalize**: Map the province's designation types to the standard `manager` categories
4. **Re-run**: `python tools/build_land_tileset.py all` and re-upload

For US data: BLM, USFS, NPS, and state park datasets are available as shapefiles/GeoJSON from federal and state open data portals. The colour palette already includes `blm`, `usfs`, `nps`, and `state_park` categories.

## Architecture

| Component       | File                                       | Role                                                       |
| --------------- | ------------------------------------------ | ---------------------------------------------------------- |
| Config          | `lib/config.dart`                          | `AppConfig.landTilesetId` from `--dart-define` / `.env`    |
| Map overlay     | `lib/screens/map/_land_overlay.dart`       | VectorSource + FillLayer + LineLayer, filter sheet, toggle |
| Offline regions | `lib/services/offline_region_service.dart` | Downloads tiles including land overlay for offline use     |
| Offline UI      | `lib/screens/offline_regions_screen.dart`  | Bounds selection, download progress, region management     |
| Data pipeline   | `tools/build_land_tileset.py`              | Download → normalize → tippecanoe → MBTiles                |
| Python deps     | `tools/land_requirements.txt`              | `requests` for HTTP downloads                              |
