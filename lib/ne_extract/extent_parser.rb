module NeExtract
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
    # @param buffer_str [String, nil] buffer value as string
    # @return [Float, nil] buffer percentage (0-100) or nil if invalid
    def parse_buffer(buffer_str)
      return 20.0 if buffer_str.nil? || buffer_str.empty?

      value = Float(buffer_str, exception: false)
      return nil unless value

      # Convert to percentage if in range (0,1)
      value *= 100 if value > 0 && value < 1

      # Validate range
      return nil if value < 0 || value > 100

      value
    end

    # Apply buffer to extent by expanding it by a percentage
    # @param extent [Hash] extent with :xmin, :ymin, :xmax, :ymax
    # @param buffer_pct [Float] buffer percentage (0-100)
    # @return [Hash] buffered extent
    def apply_buffer(extent, buffer_pct)
      width = extent[:xmax] - extent[:xmin]
      height = extent[:ymax] - extent[:ymin]

      buffer_x = width * (buffer_pct / 100.0)
      buffer_y = height * (buffer_pct / 100.0)

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
  end
end
