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
