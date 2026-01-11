require "spec_helper"
require "tmpdir"
require "json"
require_relative "../lib/natural_earth/metadata_writer"

RSpec.describe NaturalEarth::MetadataWriter do
  describe ".build_metadata" do
    let(:args_hash) do
      {
        scale: "10",
        extent: "-95,28,-88,34",
        buffer: "15",
        layers: "land,lakes",
        output: nil
      }
    end

    let(:derived_hash) do
      {
        parsed_extent: {xmin: -95.0, ymin: 28.0, xmax: -88.0, ymax: 34.0},
        buffer_config: {ew: 15.0, ns: 15.0},
        buffered_extent: {xmin: -96.05, ymin: 27.1, xmax: -86.95, ymax: 34.9},
        destination_directory: "/tmp/ne-10m--95-28--88-34",
        resolved_layers: ["land", "lakes"]
      }
    end

    let(:extraction_summary) do
      {
        total_layers: 2,
        successful: 2,
        failed: 0,
        layers: [
          {name: "land", success: true},
          {name: "lakes", success: true}
        ],
        unavailable_layers: []
      }
    end

    it "constructs complete metadata structure" do
      metadata = described_class.build_metadata(args_hash, derived_hash, extraction_summary)

      expect(metadata).to be_a(Hash)
      expect(metadata).to have_key(:command)
      expect(metadata).to have_key(:timestamp)
      expect(metadata).to have_key(:arguments)
      expect(metadata).to have_key(:derived)
      expect(metadata).to have_key(:extraction_results)
      expect(metadata).to have_key(:metadata)
    end

    it "includes original arguments" do
      metadata = described_class.build_metadata(args_hash, derived_hash, extraction_summary)

      expect(metadata[:arguments]).to eq({
        scale: "10",
        extent: "-95,28,-88,34",
        buffer: "15",
        layers: "land,lakes",
        output: nil
      })
    end

    it "includes derived values with buffer config" do
      metadata = described_class.build_metadata(args_hash, derived_hash, extraction_summary)

      expect(metadata[:derived][:parsed_extent]).to eq({
        xmin: -95.0,
        ymin: 28.0,
        xmax: -88.0,
        ymax: 34.0
      })
      expect(metadata[:derived][:buffer_config]).to eq({
        ew_percent: 15.0,
        ns_percent: 15.0
      })
      expect(metadata[:derived][:buffered_extent]).to eq({
        xmin: -96.05,
        ymin: 27.1,
        xmax: -86.95,
        ymax: 34.9
      })
    end

    it "includes only destination directory basename" do
      metadata = described_class.build_metadata(args_hash, derived_hash, extraction_summary)

      expect(metadata[:derived][:destination_directory]).to eq("ne-10m--95-28--88-34")
    end

    it "includes extraction results" do
      metadata = described_class.build_metadata(args_hash, derived_hash, extraction_summary)

      expect(metadata[:extraction_results]).to eq(extraction_summary)
    end

    it "includes version information" do
      metadata = described_class.build_metadata(args_hash, derived_hash, extraction_summary)

      expect(metadata[:metadata][:ne_version]).to eq(NaturalEarth::VERSION)
      expect(metadata[:metadata][:ruby_version]).to eq(RUBY_VERSION)
      expect(metadata[:metadata][:natural_earth_data_dir]).to eq("/Users/Shared/Geodata/ne")
    end

    it "handles dual-axis buffer config" do
      derived_hash[:buffer_config] = {ew: 20.0, ns: 30.0}
      metadata = described_class.build_metadata(args_hash, derived_hash, extraction_summary)

      expect(metadata[:derived][:buffer_config]).to eq({
        ew_percent: 20.0,
        ns_percent: 30.0
      })
    end
  end

  describe ".write_metadata" do
    let(:args_hash) do
      {
        scale: "10",
        extent: "-95,28,-88,34",
        buffer: "15",
        layers: "land,lakes",
        output: nil
      }
    end

    let(:derived_hash) do
      {
        parsed_extent: {xmin: -95.0, ymin: 28.0, xmax: -88.0, ymax: 34.0},
        buffer_config: {ew: 15.0, ns: 15.0},
        buffered_extent: {xmin: -96.05, ymin: 27.1, xmax: -86.95, ymax: 34.9},
        destination_directory: "/tmp/ne-10m--95-28--88-34",
        resolved_layers: ["land", "lakes"]
      }
    end

    let(:extraction_summary) do
      {
        total_layers: 2,
        successful: 2,
        failed: 0,
        layers: [
          {name: "land", success: true},
          {name: "lakes", success: true}
        ],
        unavailable_layers: []
      }
    end

    it "creates metadata.json file" do
      Dir.mktmpdir do |tmpdir|
        described_class.write_metadata(tmpdir, args_hash, derived_hash, extraction_summary)
        metadata_path = File.join(tmpdir, "metadata.json")

        expect(File.exist?(metadata_path)).to be true
      end
    end

    it "writes valid JSON" do
      Dir.mktmpdir do |tmpdir|
        described_class.write_metadata(tmpdir, args_hash, derived_hash, extraction_summary)
        metadata_path = File.join(tmpdir, "metadata.json")

        json_content = File.read(metadata_path)
        expect { JSON.parse(json_content) }.not_to raise_error
      end
    end

    it "writes complete metadata structure" do
      Dir.mktmpdir do |tmpdir|
        described_class.write_metadata(tmpdir, args_hash, derived_hash, extraction_summary)
        metadata_path = File.join(tmpdir, "metadata.json")

        json_content = JSON.parse(File.read(metadata_path), symbolize_names: true)

        expect(json_content).to have_key(:command)
        expect(json_content).to have_key(:timestamp)
        expect(json_content).to have_key(:arguments)
        expect(json_content).to have_key(:derived)
        expect(json_content).to have_key(:extraction_results)
        expect(json_content).to have_key(:metadata)
      end
    end
  end

  describe ".reconstruct_command" do
    it "reconstructs command with all arguments" do
      args = {
        scale: "10",
        extent: "-95,28,-88,34",
        buffer: "15",
        layers: "land,lakes",
        output: "/tmp"
      }

      command = described_class.reconstruct_command(args)

      expect(command).to eq("ne extract --scale 10 --extent -95,28,-88,34 --buffer 15 --layers land,lakes --output /tmp")
    end

    it "omits nil arguments" do
      args = {
        scale: "10",
        extent: "-95,28,-88,34",
        buffer: nil,
        layers: nil,
        output: nil
      }

      command = described_class.reconstruct_command(args)

      expect(command).to eq("ne extract --scale 10 --extent -95,28,-88,34")
    end

    it "handles dual-axis buffer" do
      args = {
        scale: "50",
        extent: "-95,28,-88,34",
        buffer: "20,30",
        layers: "default",
        output: nil
      }

      command = described_class.reconstruct_command(args)

      expect(command).to eq("ne extract --scale 50 --extent -95,28,-88,34 --buffer 20,30 --layers default")
    end
  end

  describe ".format_timestamp" do
    it "returns ISO 8601 formatted timestamp" do
      timestamp = described_class.format_timestamp

      # Should match ISO 8601 format: YYYY-MM-DDTHH:MM:SS+HH:MM
      expect(timestamp).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "includes timezone information" do
      timestamp = described_class.format_timestamp

      # Should have timezone offset
      expect(timestamp).to match(/[+-]\d{2}:\d{2}$/)
    end
  end
end
