module NaturalEarth
  # Configurable Natural Earth data directory
  # Default: /Users/Shared/Geodata/ne
  # Override: Set NE_DATA_DIR environment variable
  NE_DATA_DIR = ENV["NE_DATA_DIR"] || "/Users/Shared/Geodata/ne"
end
