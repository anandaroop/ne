module NaturalEarth
  module ExtentParser
    module_function

    # Parse extent string into a hash with xmin, ymin, xmax, ymax
    # @param extent_str [String] extent in format "xmin,ymin,xmax,ymax"
    # @return [Hash, nil] parsed extent or nil if invalid
    def parse(extent_str)
      return nil unless extent_str

      parts = extent_str.split(",").map(&:strip)
      return nil unless parts.size == 4

      coords = parts.map { |p| Float(p, exception: false) }
      return nil if coords.any?(&:nil?)

      xmin, ymin, xmax, ymax = coords
      return nil if xmin >= xmax || ymin >= ymax

      {xmin: xmin, ymin: ymin, xmax: xmax, ymax: ymax}
    end

    # Parse buffer value, converting to percentage if needed
    # Supports single value (both axes) or dual values (EW,NS)
    # @param buffer_str [String, nil] buffer value as string
    # @return [Hash, nil] buffer percentages {ew: Float, ns: Float} or nil if invalid
    def parse_buffer(buffer_str)
      return {ew: 20.0, ns: 20.0} if buffer_str.nil? || buffer_str.empty?

      parts = buffer_str.split(",").map(&:strip)

      # Single value: apply to both axes (backward compatible)
      if parts.size == 1
        value = parse_single_buffer_value(parts[0])
        return nil unless value
        return {ew: value, ns: value}
      end

      # Two values: EW and NS
      if parts.size == 2
        ew = parse_single_buffer_value(parts[0])
        ns = parse_single_buffer_value(parts[1])
        return nil unless ew && ns
        return {ew: ew, ns: ns}
      end

      nil # Invalid format (wrong number of values)
    end

    # Parse a single buffer value, converting to percentage if needed
    # @param value_str [String] buffer value as string
    # @return [Float, nil] buffer percentage (0-100) or nil if invalid
    def parse_single_buffer_value(value_str)
      value = Float(value_str, exception: false)
      return nil unless value

      # Convert to percentage if in range (0,1)
      value *= 100 if value > 0 && value < 1

      # Validate range
      return nil if value < 0 || value > 100

      value
    end

    # Apply buffer to extent by expanding it by a percentage
    # Supports independent EW and NS buffer percentages
    # @param extent [Hash] extent with :xmin, :ymin, :xmax, :ymax
    # @param buffer_config [Hash] buffer percentages {:ew => Float, :ns => Float}
    # @return [Hash] buffered extent
    def apply_buffer(extent, buffer_config)
      width = extent[:xmax] - extent[:xmin]
      height = extent[:ymax] - extent[:ymin]

      buffer_x = width * (buffer_config[:ew] / 100.0)
      buffer_y = height * (buffer_config[:ns] / 100.0)

      {
        xmin: extent[:xmin] - buffer_x,
        ymin: extent[:ymin] - buffer_y,
        xmax: extent[:xmax] + buffer_x,
        ymax: extent[:ymax] + buffer_y
      }
    end

    # Format extent as comma-separated string
    # @param extent [Hash] extent with :xmin, :ymin, :xmax, :ymax
    # @return [String] formatted extent
    def format(extent)
      "#{extent[:xmin]},#{extent[:ymin]},#{extent[:xmax]},#{extent[:ymax]}"
    end

    # Generate directory name from scale and extent
    # Rounds coordinates to integers to avoid dots in directory name
    # @param scale [String] scale value (10, 50, or 110)
    # @param extent [Hash] extent with :xmin, :ymin, :xmax, :ymax
    # @return [String] directory name
    def directory_name(scale, extent)
      xmin = extent[:xmin].round
      ymin = extent[:ymin].round
      xmax = extent[:xmax].round
      ymax = extent[:ymax].round

      "ne-#{scale}m-#{xmin}-#{ymin}-#{xmax}-#{ymax}"
    end

    # Find available directory name with sequence numbering
    # If base directory exists, appends -1, -2, etc. until finding an available name
    # @param scale [String] scale value (10, 50, or 110)
    # @param extent [Hash] extent with :xmin, :ymin, :xmax, :ymax
    # @param base_path [String, nil] base directory path (default: current directory)
    # @return [String] available directory path
    def find_available_directory(scale, extent, base_path = nil)
      dir_name = directory_name(scale, extent)
      base = base_path || Dir.pwd

      full_path = File.join(base, dir_name)
      return full_path unless Dir.exist?(full_path)

      sequence = 1
      loop do
        candidate = File.join(base, "#{dir_name}-#{sequence}")
        return candidate unless Dir.exist?(candidate)
        sequence += 1
      end
    end
  end
end
