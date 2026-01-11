require "csv"

module NaturalEarth
  module LayerResolver
    module_function

    # Extract default layers from layer map
    # @param layer_map [Hash] map of layer name => {theme:, scale:, default:}
    # @return [Array<String>] list of default layer names
    def get_default_layers(layer_map)
      layer_map.select { |_name, info| info[:default] }.keys
    end

    # Determine which layers to extract based on input string
    # @param layers_str [String, nil] comma-separated layer list, "default", or "default,extra1,extra2"
    # @param layer_map [Hash] map of available layers with default information
    # @return [Array<String>] list of layer names
    def resolve_layers(layers_str, layer_map)
      return get_default_layers(layer_map) if layers_str.nil? || layers_str.empty?

      parts = layers_str.split(",").map(&:strip).reject(&:empty?)

      if parts.include?("default")
        # Remove "default" and add all default layers plus any extras
        extras = parts - ["default"]
        get_default_layers(layer_map) + extras
      else
        parts
      end
    end

    # Build a map of available layers from CSV file
    # @param csv_path [String] path to ne.csv file
    # @param scale [String] scale to filter by (10, 50, or 110)
    # @return [Hash] map of layer name => {theme:, scale:, default:}
    def build_layer_map(csv_path, scale)
      return {} unless File.exist?(csv_path)

      layer_map = {}
      CSV.foreach(csv_path, headers: true) do |row|
        next if row["layer"].nil? || row["layer"].start_with?("ne/")
        next unless row["scale"] == scale

        layer_map[row["layer"]] = {
          theme: row["theme"],
          scale: row["scale"],
          default: row["default"]&.upcase == "TRUE"
        }
      end

      layer_map
    end

    # Filter layer list to only available layers
    # @param requested_layers [Array<String>] list of requested layer names
    # @param layer_map [Hash] map of available layers
    # @return [Hash] with :available and :unavailable arrays
    def filter_available(requested_layers, layer_map)
      available = requested_layers.select { |l| layer_map.key?(l) }
      unavailable = requested_layers - available

      {available: available, unavailable: unavailable}
    end
  end
end
