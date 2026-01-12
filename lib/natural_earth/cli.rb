require "dry/cli"
require "rainbow"
require "csv"
require "fileutils"

module NaturalEarth
  module CLI
    module Commands
      extend Dry::CLI::Registry

      # Path to the bundled ne.csv file in the gem
      NE_CSV_PATH = File.expand_path("../../ne.csv", __dir__)

      class List < Dry::CLI::Command
        desc "List available Natural Earth layers"

        option :scale, type: :string, aliases: ["s"], desc: "Filter by scale (10, 50, or 110)"
        option :theme, type: :string, aliases: ["t"], desc: "Filter by theme (physical or cultural)"
        option :default, type: :boolean, aliases: ["d"], desc: "Filter to only default layers"

        def call(scale: nil, theme: nil, default: false, **)
          # Validate scale if provided
          if scale && !["10", "50", "110"].include?(scale)
            puts Rainbow("Error: Scale must be 10, 50, or 110").red
            return
          end

          # Validate theme if provided
          if theme && !["physical", "cultural"].include?(theme)
            puts Rainbow("Error: Theme must be physical or cultural").red
            return
          end

          # Read and parse CSV file
          unless File.exist?(NE_CSV_PATH)
            puts Rainbow("Error: Could not find ne.csv data file").red
            return
          end

          layers = []
          CSV.foreach(NE_CSV_PATH, headers: true) do |row|
            # Skip malformed entries (e.g., those with paths)
            next if row["layer"].nil? || row["layer"].start_with?("ne/")
            # Filter by scale if provided
            next if scale && row["scale"] != scale
            # Filter by theme if provided
            next if theme && row["theme"] != theme

            is_default = row["default"]&.upcase == "TRUE"
            # Filter by default if provided
            next if default && !is_default

            layers << {
              scale: row["scale"],
              theme: row["theme"],
              layer: row["layer"],
              default: is_default
            }
          end

          # Display results
          if layers.empty?
            filters = []
            filters << "scale #{scale}" if scale
            filters << "theme #{theme}" if theme
            filters << "default layers" if default

            if filters.any?
              puts Rainbow("No layers found for #{filters.join(", ")}").yellow
            else
              puts Rainbow("No layers found").yellow
            end
            return
          end

          # Print header
          filters = []
          filters << "#{scale}m scale" if scale
          filters << "#{theme} theme" if theme
          filters << "default layers" if default

          if filters.any?
            puts Rainbow("\nNatural Earth Layers (#{filters.join(", ")}):\n").bright.cyan
          else
            puts Rainbow("\nNatural Earth Layers:\n").bright.cyan
          end

          # Group by scale and theme for better readability
          layers.group_by { |l| l[:scale] }.sort.each do |s, scale_layers|
            puts Rainbow("\n#{s}m Scale (1:#{s},000,000):").bright.white

            scale_layers.group_by { |l| l[:theme] }.sort.each do |theme, theme_layers|
              puts Rainbow("  #{theme.capitalize}:").yellow
              theme_layers.sort_by { |l| l[:layer] }.each do |layer|
                if layer[:default]
                  puts "    " + Rainbow(layer[:layer]).bright.green.bold
                else
                  puts "    #{layer[:layer]}"
                end
              end
            end
          end

          puts Rainbow("\nTotal: #{layers.size} layers\n").bright.cyan
        end
      end

      class Extract < Dry::CLI::Command
        desc "Extract Natural Earth data for a specific extent"

        option :scale, type: :string, required: true, aliases: ["s"], desc: "Scale: 10, 50, or 110"
        option :extent, type: :string, required: true, aliases: ["e"], desc: "Spatial extent: xmin,ymin,xmax,ymax"
        option :buffer, type: :string, aliases: ["b"], desc: "Expand extent by percentage (default: 20). Single value applies to both axes; two values (EW,NS) allow independent control"
        option :layers, type: :string, aliases: ["l"], desc: "Comma-separated layer list (default: standard basemap layers)"
        option :output, type: :string, aliases: ["o"], desc: "Output directory (default: current directory)"

        def call(scale: nil, extent: nil, buffer: nil, layers: nil, output: nil, **)
          # Store original arguments for metadata
          original_args = {
            scale: scale,
            extent: extent,
            buffer: buffer,
            layers: layers,
            output: output
          }

          # Validate scale
          unless ["10", "50", "110"].include?(scale)
            print_scale_reminder
            return
          end

          # Validate and normalize output directory
          output_dir = validate_output_directory(output)
          return unless output_dir

          # Parse and validate extent
          parsed_extent = ExtentParser.parse(extent)
          unless parsed_extent
            puts Rainbow("Error: Invalid extent format. Use: xmin,ymin,xmax,ymax").red
            return
          end

          # Parse buffer (default 20%)
          buffer_config = ExtentParser.parse_buffer(buffer)
          unless buffer_config
            puts Rainbow("Error: Invalid buffer format").red
            puts "  Single value: --buffer 20     (applies 20% to both axes)"
            puts "  Dual values:  --buffer 20,30  (20% EW, 30% NS)"
            puts "  Values must be between 0-100 or 0.0-1.0"
            return
          end

          # Calculate buffered extent
          buffered_extent = ExtentParser.apply_buffer(parsed_extent, buffer_config)

          # Build layer map from CSV
          layer_map = LayerResolver.build_layer_map(NE_CSV_PATH, scale)
          if layer_map.empty?
            puts Rainbow("Error: Could not read layer information from ne.csv").red
            return
          end

          # Determine layers to extract
          layer_list = LayerResolver.resolve_layers(layers, layer_map)
          if layer_list.empty?
            puts Rainbow("Error: No valid layers specified").red
            return
          end

          # Filter to available layers
          filtered = LayerResolver.filter_available(layer_list, layer_map)
          available_layers = filtered[:available]
          unavailable_layers = filtered[:unavailable]

          if available_layers.empty?
            puts Rainbow("Error: None of the specified layers are available at scale #{scale}").red
            puts "Unavailable layers: #{unavailable_layers.join(", ")}" unless unavailable_layers.empty?
            return
          end

          # Find available destination directory (with sequence number if needed)
          dest_dir = ExtentParser.find_available_directory(scale, parsed_extent, output_dir)
          Dir.mkdir(dest_dir)

          puts Rainbow("\nExtracting to: #{dest_dir}").bright.cyan
          puts Rainbow("Scale: #{scale}m (1:#{scale},000,000)").white
          puts Rainbow("Original extent: #{ExtentParser.format(parsed_extent)}").white

          # Format buffer display
          buffer_display = if buffer_config[:ew] == buffer_config[:ns]
            "#{buffer_config[:ew]}% buffer"
          else
            "#{buffer_config[:ew]}% EW, #{buffer_config[:ns]}% NS buffer"
          end
          puts Rainbow("Buffered extent: #{ExtentParser.format(buffered_extent)} (#{buffer_display})").white
          puts Rainbow("Layers: #{available_layers.size}").white

          if unavailable_layers.any?
            puts Rainbow("\nSkipping unavailable layers: #{unavailable_layers.join(", ")}").yellow
          end

          puts ""

          # Extract each layer
          success_count = 0
          extraction_results = []
          available_layers.each_with_index do |layer, idx|
            layer_info = layer_map[layer]
            source_path = File.join(NaturalEarth::NE_DATA_DIR, "#{scale}m_#{layer_info[:theme]}", "ne_#{scale}m_#{layer}.shp")

            print "  [#{idx + 1}/#{available_layers.size}] #{layer}... "

            success = extract_layer(source_path, dest_dir, buffered_extent)
            extraction_results << {name: layer, success: success}

            if success
              puts Rainbow("✓").green
              success_count += 1
            else
              puts Rainbow("✗").red
            end
          end

          puts ""

          # Write metadata.json
          begin
            derived_data = {
              parsed_extent: parsed_extent,
              buffer_config: buffer_config,
              buffered_extent: buffered_extent,
              destination_directory: dest_dir,
              resolved_layers: available_layers
            }

            extraction_summary = {
              total_layers: available_layers.size,
              successful: success_count,
              failed: available_layers.size - success_count,
              layers: extraction_results,
              unavailable_layers: unavailable_layers
            }

            MetadataWriter.write_metadata(
              dest_dir,
              original_args,
              derived_data,
              extraction_summary
            )
          rescue => e
            puts Rainbow("⚠ Could not write metadata.json: #{e.message}").yellow
          end

          if success_count == available_layers.size
            puts Rainbow("✓ Successfully extracted #{success_count} layers").green
          else
            puts Rainbow("⚠ Extracted #{success_count}/#{available_layers.size} layers").yellow
          end
        end

        private

        def validate_output_directory(output)
          # Default to current working directory if not specified
          dir = output || Dir.pwd

          # Expand path to handle ~ and relative paths
          expanded_dir = File.expand_path(dir)

          # Check if directory exists
          unless Dir.exist?(expanded_dir)
            puts Rainbow("Error: Output directory does not exist: #{expanded_dir}").red
            return nil
          end

          # Check if directory is writable
          unless File.writable?(expanded_dir)
            puts Rainbow("Error: Output directory is not writable: #{expanded_dir}").red
            return nil
          end

          expanded_dir
        end

        def extract_layer(source_path, dest_dir, extent)
          unless File.exist?(source_path)
            warn "    Source file not found: #{source_path}" if ENV["DEBUG"]
            return false
          end

          cmd = [
            "ogr2ogr",
            "-spat", extent[:xmin].to_s, extent[:ymin].to_s, extent[:xmax].to_s, extent[:ymax].to_s,
            "-clipsrc", "spat_extent",
            dest_dir,
            source_path
          ]

          if ENV["DEBUG"]
            warn "    Command: #{cmd.join(" ")}"
            system(*cmd)
          else
            system(*cmd, out: File::NULL, err: File::NULL)
          end
        end

        def print_scale_reminder
          puts Rainbow("\nError: --scale is required\n").red
          puts "Scale options:"
          puts "  #{Rainbow("10").bright}  - 1:10,000,000, largest scale, greatest detail"
          puts "  #{Rainbow("50").bright}  - 1:50,000,000, intermediate scale, moderate detail"
          puts "  #{Rainbow("110").bright} - 1:110,000,000, smallest scale, least detail"
          puts ""
        end
      end

      class Clean < Dry::CLI::Command
        desc "Clean up Natural Earth output directories from the current directory"

        def call(**)
          # Find all directories matching the pattern
          output_dirs = find_output_directories(Dir.pwd)

          if output_dirs.empty?
            puts Rainbow("No Natural Earth output directories found in current directory").yellow
            return
          end

          # Display directories to be deleted
          puts Rainbow("\nThe following directories will be deleted:").bright.cyan
          output_dirs.each do |dir|
            puts "  #{File.basename(dir)}"
          end
          puts ""

          # Confirm with user
          print "Delete these #{output_dirs.size} directories? (y/N): "
          response = $stdin.gets.chomp.downcase

          unless ["y", "yes"].include?(response)
            puts Rainbow("Cancelled. No directories were deleted.").yellow
            return
          end

          # Delete directories
          success_count = 0
          output_dirs.each do |dir|
            if delete_directory(dir)
              success_count += 1
            else
              puts Rainbow("  Failed to delete: #{File.basename(dir)}").red
            end
          end

          puts ""
          if success_count == output_dirs.size
            puts Rainbow("✓ Successfully deleted #{success_count} directories").green
          else
            puts Rainbow("⚠ Deleted #{success_count}/#{output_dirs.size} directories").yellow
          end
        end

        private

        # Find all output directories matching the naming pattern
        # Pattern: ne-{scale}m-{xmin}-{ymin}-{xmax}-{ymax}[-sequence]
        # Examples: ne-10m--95-28--88-34, ne-50m--92-28--88-32-1
        def find_output_directories(base_path)
          # Regex to match the directory pattern
          # Scale: 10, 50, or 110
          # Each coordinate is separated by a dash, and can be negative (resulting in --)
          # Optional sequence number at the end
          pattern = /^ne-(10|50|110)m-(-?\d+)-(-?\d+)-(-?\d+)-(-?\d+)(-\d+)?$/

          Dir.entries(base_path)
            .select { |entry| File.directory?(File.join(base_path, entry)) }
            .select { |entry| entry.match?(pattern) }
            .map { |entry| File.join(base_path, entry) }
            .sort
        end

        def delete_directory(dir)
          FileUtils.rm_rf(dir)
          true
        rescue => e
          warn "Error deleting #{dir}: #{e.message}" if ENV["DEBUG"]
          false
        end
      end

      class Version < Dry::CLI::Command
        desc "Show version information"

        def call(**)
          puts "ne version #{NaturalEarth::VERSION}"
        end
      end

      class Examples < Dry::CLI::Command
        desc "Show example usage commands"

        EXAMPLES = [
          {comment: "show all available layers", command: "ne list"},
          {comment: "show all available layers for 1:10,000,000 scale", command: "ne list --scale 10"},
          {comment: "show only default layers for 1:10,000,000 scale", command: "ne list --scale 10 --default"},
          {comment: "show only cultural layers for 1:10,000,000 scale", command: "ne list --scale 10 --theme cultural"},
          {comment: "extract a coarse basemap of USA", command: "ne extract --scale 110 --extent -124,24,-66,49"},
          {comment: "extract a detailed basemap of Louisiana", command: "ne extract --scale 10 --extent -95,28,-88,34"},
          {comment: "extract a detailed basemap of Louisiana, with a 15% buffer", command: "ne extract --scale 10 --extent -95,28,-88,34 --buffer 15"},
          {comment: "extract a detailed basemap of Louisiana, with independent EW/NS buffers", command: "ne extract --scale 10 --extent -95,28,-88,34 --buffer 25,15"},
          {comment: "extract a detailed basemap of Louisiana, but only the land and ocean layers", command: "ne extract --scale 10 --extent -95,28,-88,34 --layers land,ocean"},
          {comment: "extract a detailed basemap of Louisiana, with default layers plus populated places", command: "ne extract --scale 10 --extent -95,28,-88,34 --layers default,populated_places"},
          {comment: "extract a detailed basemap of Louisiana, but write to a separate output dir", command: "ne extract --scale 10 --extent -95,28,-88,34 --output ~/tmp"}
        ]

        def call(**)
          puts ""
          EXAMPLES.each do |item|
            puts Rainbow("# #{item[:comment]}").green.bold
            puts Rainbow(item[:command])
            puts ""
          end
        end
      end

      register "list", List, aliases: ["l"]
      register "extract", Extract, aliases: ["e"]
      register "clean", Clean
      register "version", Version
      register "examples", Examples, aliases: ["tldr"]
    end
  end
end
