# ne

A command-line application to extract vector basemap data from the Natural Earth dataset.

This wraps the (already installed) `ogr2ogr` utility from the GDAL package.

This uses the (already installed) local copy of Natural Earth.

The main use case is: quickly extract relevant data from Natural Earth in shapefile format, e.g.

```sh
ne extract --scale 110 --extent -92,28,-88,32 --buffer 0.15 --layers land,lakes,rivers_lake_centerlines_scale_rank,populated_places_simple
ne extract --scale 110 --extent -92,28,-88,32 --buffer 0.15 --layers default,glaciated_areas
```

### Current State: Is this a new project being started, or does existing code need enhancement/fixing?

Primary Use Case: What's the main problem this tool solves? (e.g., "quickly extract coastlines at 1:10m scale as GeoJSON")

## Development Guidelines

### Language & Tools

- **Language**: Ruby 3.4.5 (managed via Mise-en-place)
- **Package**: Rubygem
- **Framework**: dry-cli
- **Linting**: StandardRB
- **Testing**: RSpec
- **Task Runner**: Rakefile
- **Output**: Rainbow

### Workflow

- **Commits**: Use Conventional Commits format (feat:, fix:, docs:, etc.)
- **Testing**: Run `bundle exec rake` to run tests and linter before committing

### Available Rake Tasks

- `rake` - Default: runs tests and linter
- `rake spec` - Run RSpec tests only
- `rake lint` - Run StandardRB linter
- `rake fix` - Auto-fix StandardRB issues

## Implementation details

- Natural Earth dataset is at `/Users/Shared/Geodata/ne`
- `./ne.csv` contains a summary of all available thematic layers with the column headers:
  - `scale` indicates 10m, 50m or 110m
  - `theme` whether physical or cultural
  - `layer` layer name from Natural Earth

### Deriving the destination directory

The destination folder should be derived from the scale and extent, with coordinates rounded to integers (to avoid `.` characters which confuse ogr2ogr). For example:

- if the xmin,ymin,xmax,ymax extent is `-95.0,28.0,-87.7,33.8` and the scale is `10`
- then the destination folder is `ne-10m--95-28--88-34` (coordinates rounded to nearest integer)

### Sample of `ogr2ogr` usage

The general pattern for each layer being extracter is:

```
ogr2ogr -spat <extent> -clipsrc spat_extent <destination folder> /Users/Shared/Geodata/ne/<source data layer>
```

Specific examples:

```sh
ogr2ogr -spat -95.0 28.0 -87.7 33.8 -clipsrc spat_extent ne-10m--95-28--88-34 /Users/Shared/Geodata/ne/10m_physical/ne_10m_land.shp
ogr2ogr -spat -95.0 28.0 -87.7 33.8 -clipsrc spat_extent ne-10m--95-28--88-34 /Users/Shared/Geodata/ne/10m_cultural/ne_10m_admin_0_countries.shp
ogr2ogr -spat -95.0 28.0 -87.7 33.8 -clipsrc spat_extent ne-10m--95-28--88-34 /Users/Shared/Geodata/ne/10m_cultural/ne_10m_admin_0_boundary_lines_land.shp
```

## User stories

### Show usage info

`ne`

- Shows usage info

### List available data

`ne list` (or `ne l`)

- Lists all available data from the summary in `./ne.csv`
- If a layer is one of the default layers as indicated by the `default` boolean column, ensure it displays more prominently in the listing

#### Arguments

- optional arg `--scale` or `-s`

  - if present, filter the data to only that scale

- optional arg `--theme` or `-t`

  - one of `physical` or `cultural`
  - if present, filter the data to only the layers in that theme

- optional arg `--default` or `-d`

  - if present, filter the data to only default layers

### Extract selected data

`ne extract` (or `ne e`)

#### Arguments

- required arg `--scale` or `-s`

  - one of 10, 50 or 110 -- corresponding to the 1:10,000,000 or 1:50,000,000 or 1:110,000,000 datasets
  - if omitted, ensure that the usage feedback to the user reminds them:
    - `10m` - 1:10,000,000, largest scale, greatest detail
    - `50m` - 1:50,000,000, intermediate scale, moderate detail
    - `110m` - 1:110,000,000, smallest scale, least detail

- required arg `--extent` or `-e`

  - spatial extent in the comma-separated form `<xmin>,<ymin>,<xmax>,<ymax>`

- optional arg `--buffer` or `-b`

  - expand the spatial extent by this amount
  - if no value is provided, default to 20%
  - either of
    - a number in the range (0,1)
      - interpret as a percentage, e.g. `0.25` => 25%
    - a number in the range (1,100)
      - interpret as a percentage, e.g. `25` => 25%
  - use this factor to scale the spatial extent to a large rectangle

- optional arg `--layers` or `-l`

  - if not provided, assume a default set of layers:
    - `land`
    - `lakes`
    - `rivers_lake_centerlines_scale_rank`
    - `admin_0_countries`
    - `admin_0_boundary_lines_disputed_areas`
    - `admin_0_boundary_lines_land`
    - `admin_1_states_provinces_scale_rank`
    - `admin_1_states_provinces_lines`
  - if `--layers default` is provided, assume the same set of default layers
  - if `--layers layer1,layer2,layer3,etc` is provided, use the comma-separated list of layers
  - if `--layers default,layer1,layer2,etc` is provided, use the default set plus the extra comma-separated list of layers

- optional arg `--output` or `-o`
  - allows data to be written to any directory, not just current working dir
  - if provided, create the destination folder as a subfolder in the provided path

### Clean up the working dir

`ne clean` (no shortcut)

- determine the list of output folders in the current directory, e.g. the ones that look something like `ne-50m--92-28--88-32-1`
- confirm with the user the full list of deletions
- if confirmed, delete those directories
- be sure the folder detection logic matches the folder naming logic

### Show tldr example usage

`ne examples` (or `ne tldr`)

- show a list of example commands with comments

- pretty print them so that comments are quieter than the commands
