require "dry/cli"
require "rainbow"

module NeExtract
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class List < Dry::CLI::Command
        desc "List available Natural Earth layers"

        option :scale, type: :string, aliases: ["s"], desc: "Filter by scale (10, 50, or 110)"

        def call(scale: nil, **)
          puts Rainbow("List command - to be implemented").yellow
          puts "Scale filter: #{scale}" if scale
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
