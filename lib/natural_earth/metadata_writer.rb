require "json"
require "time"

module NaturalEarth
  module MetadataWriter
    module_function

    # Write metadata to JSON file in destination directory
    # @param dest_dir [String] destination directory path
    # @param args_hash [Hash] original arguments passed to command
    # @param derived_hash [Hash] derived values (parsed extent, buffer config, etc.)
    # @param extraction_summary [Hash] extraction results summary
    # @return [void]
    def write_metadata(dest_dir, args_hash, derived_hash, extraction_summary)
      metadata = build_metadata(args_hash, derived_hash, extraction_summary)
      metadata_path = File.join(dest_dir, "metadata.json")

      File.write(metadata_path, JSON.pretty_generate(metadata))
    end

    # Build complete metadata hash
    # @param args_hash [Hash] original arguments passed to command
    # @param derived_hash [Hash] derived values (parsed extent, buffer config, etc.)
    # @param extraction_summary [Hash] extraction results summary
    # @return [Hash] complete metadata structure
    def build_metadata(args_hash, derived_hash, extraction_summary)
      {
        command: reconstruct_command(args_hash),
        timestamp: format_timestamp,
        arguments: {
          scale: args_hash[:scale],
          extent: args_hash[:extent],
          buffer: args_hash[:buffer],
          layers: args_hash[:layers],
          output: args_hash[:output]
        },
        derived: {
          parsed_extent: derived_hash[:parsed_extent],
          buffer_config: {
            ew_percent: derived_hash[:buffer_config][:ew],
            ns_percent: derived_hash[:buffer_config][:ns]
          },
          buffered_extent: derived_hash[:buffered_extent],
          destination_directory: File.basename(derived_hash[:destination_directory]),
          resolved_layers: derived_hash[:resolved_layers]
        },
        extraction_results: extraction_summary,
        metadata: {
          ne_version: VERSION,
          ruby_version: RUBY_VERSION,
          natural_earth_data_dir: NaturalEarth::NE_DATA_DIR
        }
      }
    end

    # Reconstruct command string from arguments
    # Uses canonical long-form option names
    # @param args_hash [Hash] original arguments
    # @return [String] reconstructed command string
    def reconstruct_command(args_hash)
      parts = ["ne extract"]

      parts << "--scale #{args_hash[:scale]}" if args_hash[:scale]
      parts << "--extent #{args_hash[:extent]}" if args_hash[:extent]
      parts << "--buffer #{args_hash[:buffer]}" if args_hash[:buffer]
      parts << "--layers #{args_hash[:layers]}" if args_hash[:layers]
      parts << "--output #{args_hash[:output]}" if args_hash[:output]

      parts.join(" ")
    end

    # Generate ISO 8601 timestamp with timezone
    # @return [String] formatted timestamp
    def format_timestamp
      Time.now.iso8601
    end
  end
end
