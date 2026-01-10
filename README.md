# ne-extract

A command-line tool for extracting vector basemap data from the Natural Earth dataset.

`ne-extract` wraps the GDAL `ogr2ogr` utility to quickly extract relevant geospatial layers from Natural Earth in shapefile format for a specific geographic extent.

## Features

- Extract multiple Natural Earth layers for a specific geographic extent
- Choose from three detail levels: 1:10m, 1:50m, or 1:110m scale
- Apply buffer around your extent for context
- Default basemap layer set or custom layer selection
- List all available layers by scale
- Automatically prevents overwriting existing extractions with sequence numbering
- Specify custom output directory

## Prerequisites

Before installing `ne-extract`, you need:

1. **Ruby 3.4.5 or later**
2. **GDAL** with the `ogr2ogr` utility installed
   - macOS: `brew install gdal`
   - Ubuntu/Debian: `apt-get install gdal-bin`
   - Check installation: `ogr2ogr --version`
3. **Natural Earth dataset** installed locally at `/Users/Shared/Geodata/ne`
4. **ne.csv file** in your working directory (lists available layers)

## Installation

Clone the repository and install as a local gem:

```bash
git clone https://github.com/yourusername/ne-extract.git
cd ne-extract
bundle install
bundle exec rake install  # installs onto your system
```

## Usage

### List Available Layers

View all available Natural Earth layers:

```bash
ne list
```

Filter by scale:

```bash
ne list --scale 110
ne list -s 50
```

### Extract Data

Extract Natural Earth data for a specific geographic extent:

```bash
ne extract --scale 110 --extent -92,28,-88,32
```

#### Required Options

- `--scale` or `-s`: Scale of the data
  - `10` - 1:10,000,000 (largest scale, greatest detail)
  - `50` - 1:50,000,000 (intermediate scale, moderate detail)
  - `110` - 1:110,000,000 (smallest scale, least detail)

- `--extent` or `-e`: Geographic bounding box in the format `xmin,ymin,xmax,ymax`
  - Example: `-95.0,28.0,-87.7,33.8` (Gulf Coast region)

#### Optional Options

- `--buffer` or `-b`: Expand the extent by a percentage (default: 20%)
  - Specify as decimal: `0.15` (15%)
  - Specify as percentage: `25` (25%)
  - Example: `--buffer 0.15` or `--buffer 15`

- `--layers` or `-l`: Comma-separated list of layers to extract
  - Default layers (if omitted):
    - `land`
    - `lakes`
    - `rivers_lake_centerlines_scale_rank`
    - `admin_0_countries`
    - `admin_0_boundary_lines_disputed_areas`
    - `admin_0_boundary_lines_land`
    - `admin_1_states_provinces_scale_rank`
    - `admin_1_states_provinces_lines`
  - Use `default` to include default layers: `--layers default`
  - Specify custom layers: `--layers land,lakes,coastline`
  - Combine default + extras: `--layers default,glaciated_areas,populated_places`

- `--output` or `-o`: Output directory (default: current directory)
  - Absolute path: `--output /path/to/output`
  - Relative path: `--output ../extracts`
  - Home directory: `--output ~/geodata`

### Examples

#### Basic extraction with defaults

Extract Gulf Coast region at 1:110m scale with default layers and 20% buffer:

```bash
ne extract --scale 110 --extent -95,28,-88,32
```

#### Custom buffer

Extract with 15% buffer:

```bash
ne extract --scale 110 --extent -92,28,-88,32 --buffer 0.15
```

#### Custom layers

Extract specific layers:

```bash
ne extract --scale 110 --extent -92,28,-88,32 --layers land,lakes,rivers_lake_centerlines_scale_rank,populated_places_simple
```

#### Default layers plus extras

Add glaciated areas to the default layer set:

```bash
ne extract --scale 110 --extent -92,28,-88,32 --layers default,glaciated_areas
```

#### High detail extraction

Extract at 1:10m scale for maximum detail:

```bash
ne extract --scale 10 --extent -95,28,-88,32 --buffer 25
```

#### Custom output directory

Extract to a specific directory:

```bash
ne extract --scale 110 --extent -92,28,-88,32 --output ~/geodata/extracts
```

## Output

Extracted data is saved to a directory named based on the scale and extent:

```
ne-110m--92-28--88-32/
```

If the directory already exists, a sequence number is automatically appended:

```
ne-110m--92-28--88-32-1/
ne-110m--92-28--88-32-2/
```

Each directory contains the extracted layers as shapefiles with their associated files (.shp, .dbf, .shx, .prj).

## Troubleshooting

### "ne.csv not found in current directory"

The `ne.csv` file must be present in your current working directory when running `ne list` or `ne extract`. This file contains the catalog of available Natural Earth layers.

### "ogr2ogr command not found"

GDAL is not installed or not in your PATH. Install GDAL using your system's package manager.

### "Source file not found"

The Natural Earth dataset is not installed at the expected location (`/Users/Shared/Geodata/ne`), or the specific layer is not available at the requested scale. Use `ne list --scale <scale>` to see available layers.

### "Output directory does not exist"

When using `--output`, ensure the directory exists before running the extraction. The tool will not create the parent directory, only the extraction subdirectory.

## Development

See [AGENTS.md](AGENTS.md) for development guidelines and project structure.

### Running Tests

```bash
bundle exec rake           # Run tests and linter
bundle exec rake spec      # Run tests only
bundle exec rake lint      # Run linter only
bundle exec rake fix       # Auto-fix linter issues
```

## License

MIT
