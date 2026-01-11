# ne

A command-line application to extract vector basemap data from the Natural Earth dataset.

This wraps the (already installed) `ogr2ogr` utility from the GDAL package.

This uses the (already installed) local copy of Natural Earth.

The main use case is: quickly extract relevant data from Natural Earth in shapefile format, e.g.

```sh
ne extract --scale 110 --extent -92,28,-88,32 --buffer 0.15 --layers land,lakes,rivers_lake_centerlines_scale_rank,populated_places_simple
ne extract --scale 110 --extent -92,28,-88,32 --buffer 0.15 --layers default,glaciated_areas
```

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
- **Verifying**: Run the WIP command locally with `./bin/ne [options]` to verify current behavior

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

Common user stories are documented in @STORIES.md. New ones to be implemented may be added there as well.
