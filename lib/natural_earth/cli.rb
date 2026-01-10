require "dry/cli"
require "rainbow"
require "csv"

module NaturalEarth
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class List < Dry::CLI::Command
        desc "List available Natural Earth layers"

        option :scale, type: :string, aliases: ["s"], desc: "Filter by scale (10, 50, or 110)"

        def call(scale: nil, **)
          # Validate scale if provided
          if scale && !["10", "50", "110"].include?(scale)
            puts Rainbow("Error: Scale must be 10, 50, or 110").red
            return
          end

          # Read and parse CSV file
          csv_path = File.join(Dir.pwd, "ne.csv")
          unless File.exist?(csv_path)
            puts Rainbow("Error: ne.csv not found in current directory").red
            return
          end

          layers = []
          CSV.foreach(csv_path, headers: true) do |row|
            # Skip malformed entries (e.g., those with paths)
            next if row["layer"].nil? || row["layer"].start_with?("ne/")
            # Filter by scale if provided
            next if scale && row["scale"] != scale

            layers << {
              scale: row["scale"],
              theme: row["theme"],
              layer: row["layer"]
            }
          end

          # Display results
          if layers.empty?
            if scale
              puts Rainbow("No layers found for scale #{scale}").yellow
            else
              puts Rainbow("No layers found").yellow
            end
            return
          end

          # Print header
          if scale
            puts Rainbow("\nNatural Earth Layers (#{scale}m scale):\n").bright.cyan
          else
            puts Rainbow("\nNatural Earth Layers:\n").bright.cyan
          end

          # Group by scale and theme for better readability
          layers.group_by { |l| l[:scale] }.sort.each do |s, scale_layers|
            puts Rainbow("\n#{s}m Scale (1:#{s},000,000):").bright.white

            scale_layers.group_by { |l| l[:theme] }.sort.each do |theme, theme_layers|
              puts Rainbow("  #{theme.capitalize}:").yellow
              theme_layers.sort_by { |l| l[:layer] }.each do |layer|
                puts "    #{layer[:layer]}"
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
        option :buffer, type: :string, aliases: ["b"], desc: "Expand extent by percentage (default: 20)"
        option :layers, type: :string, aliases: ["l"], desc: "Comma-separated layer list (default: standard basemap layers)"
        option :output, type: :string, aliases: ["o"], desc: "Output directory (default: current directory)"

        NE_DATA_DIR = "/Users/Shared/Geodata/ne"

        def call(scale: nil, extent: nil, buffer: nil, layers: nil, output: nil, **)
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
          buffer_pct = ExtentParser.parse_buffer(buffer)
          unless buffer_pct
            puts Rainbow("Error: Invalid buffer format. Use a number between 0-100 or 0.0-1.0").red
            return
          end

          # Calculate buffered extent
          buffered_extent = ExtentParser.apply_buffer(parsed_extent, buffer_pct)

          # Determine layers to extract
          layer_list = LayerResolver.resolve_layers(layers)
          if layer_list.empty?
            puts Rainbow("Error: No valid layers specified").red
            return
          end

          # Build layer map from CSV
          csv_path = File.join(Dir.pwd, "ne.csv")
          layer_map = LayerResolver.build_layer_map(csv_path, scale)
          if layer_map.empty?
            puts Rainbow("Error: Could not read layer information from ne.csv").red
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
          puts Rainbow("Buffered extent: #{ExtentParser.format(buffered_extent)} (#{buffer_pct}% buffer)").white
          puts Rainbow("Layers: #{available_layers.size}").white

          if unavailable_layers.any?
            puts Rainbow("\nSkipping unavailable layers: #{unavailable_layers.join(", ")}").yellow
          end

          puts ""

          # Extract each layer
          success_count = 0
          available_layers.each_with_index do |layer, idx|
            layer_info = layer_map[layer]
            source_path = File.join(NE_DATA_DIR, "#{scale}m_#{layer_info[:theme]}", "ne_#{scale}m_#{layer}.shp")

            print "  [#{idx + 1}/#{available_layers.size}] #{layer}... "

            if extract_layer(source_path, dest_dir, buffered_extent)
              puts Rainbow("✓").green
              success_count += 1
            else
              puts Rainbow("✗").red
            end
          end

          puts ""
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

      register "list", List, aliases: ["l"]
      register "extract", Extract, aliases: ["e"]
    end
  end
end
