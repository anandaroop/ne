require "dry/cli"
require "rainbow"
require "csv"

module NeExtract
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

        def call(scale: nil, extent: nil, buffer: nil, layers: nil, **)
          unless scale
            print_scale_reminder
            return
          end

          puts Rainbow("Extract command - to be implemented").yellow
          puts "Scale: #{scale}"
          puts "Extent: #{extent}"
          puts "Buffer: #{buffer}" if buffer
          puts "Layers: #{layers}" if layers
        end

        private

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
