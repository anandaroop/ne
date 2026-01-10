require "spec_helper"
require_relative "../lib/ne_extract/extent_parser"

RSpec.describe NeExtract::ExtentParser do
  describe ".parse" do
    it "parses valid extent string" do
      result = described_class.parse("-95.0,28.0,-87.7,33.8")
      expect(result).to eq({
        xmin: -95.0,
        ymin: 28.0,
        xmax: -87.7,
        ymax: 33.8
      })
    end

    it "parses extent with spaces" do
      result = described_class.parse("-95.0, 28.0, -87.7, 33.8")
      expect(result).to eq({
        xmin: -95.0,
        ymin: 28.0,
        xmax: -87.7,
        ymax: 33.8
      })
    end

    it "parses integer coordinates" do
      result = described_class.parse("-95,28,-88,34")
      expect(result).to eq({
        xmin: -95.0,
        ymin: 28.0,
        xmax: -88.0,
        ymax: 34.0
      })
    end

    it "returns nil for nil input" do
      expect(described_class.parse(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.parse("")).to be_nil
    end

    it "returns nil for wrong number of coordinates" do
      expect(described_class.parse("-95.0,28.0,-87.7")).to be_nil
      expect(described_class.parse("-95.0,28.0,-87.7,33.8,100")).to be_nil
    end

    it "returns nil for non-numeric coordinates" do
      expect(described_class.parse("-95.0,abc,-87.7,33.8")).to be_nil
    end

    it "returns nil when xmin >= xmax" do
      expect(described_class.parse("-87.7,28.0,-95.0,33.8")).to be_nil
      expect(described_class.parse("-95.0,28.0,-95.0,33.8")).to be_nil
    end

    it "returns nil when ymin >= ymax" do
      expect(described_class.parse("-95.0,33.8,-87.7,28.0")).to be_nil
      expect(described_class.parse("-95.0,28.0,-87.7,28.0")).to be_nil
    end
  end

  describe ".parse_buffer" do
    it "returns default 20% for nil input" do
      expect(described_class.parse_buffer(nil)).to eq(20.0)
    end

    it "returns default 20% for empty string" do
      expect(described_class.parse_buffer("")).to eq(20.0)
    end

    it "parses percentage values 0-100" do
      expect(described_class.parse_buffer("0")).to eq(0.0)
      expect(described_class.parse_buffer("15")).to eq(15.0)
      expect(described_class.parse_buffer("50")).to eq(50.0)
      expect(described_class.parse_buffer("100")).to eq(100.0)
    end

    it "converts decimal values 0-1 to percentages" do
      expect(described_class.parse_buffer("0.15")).to eq(15.0)
      expect(described_class.parse_buffer("0.25")).to eq(25.0)
      expect(described_class.parse_buffer("0.5")).to eq(50.0)
    end

    it "returns nil for negative values" do
      expect(described_class.parse_buffer("-10")).to be_nil
    end

    it "returns nil for values over 100" do
      expect(described_class.parse_buffer("101")).to be_nil
      expect(described_class.parse_buffer("200")).to be_nil
    end

    it "returns nil for non-numeric values" do
      expect(described_class.parse_buffer("abc")).to be_nil
    end
  end

  describe ".apply_buffer" do
    let(:extent) do
      {xmin: -95.0, ymin: 28.0, xmax: -87.0, ymax: 34.0}
    end

    it "applies 0% buffer (no change)" do
      result = described_class.apply_buffer(extent, 0.0)
      expect(result).to eq(extent)
    end

    it "applies 20% buffer" do
      result = described_class.apply_buffer(extent, 20.0)

      # Original extent: width=8.0, height=6.0
      # 20% buffer: buffer_x=1.6, buffer_y=1.2
      expect(result[:xmin]).to be_within(0.01).of(-96.6)
      expect(result[:ymin]).to be_within(0.01).of(26.8)
      expect(result[:xmax]).to be_within(0.01).of(-85.4)
      expect(result[:ymax]).to be_within(0.01).of(35.2)
    end

    it "applies 50% buffer" do
      result = described_class.apply_buffer(extent, 50.0)

      # Original extent: width=8.0, height=6.0
      # 50% buffer: buffer_x=4.0, buffer_y=3.0
      expect(result[:xmin]).to be_within(0.01).of(-99.0)
      expect(result[:ymin]).to be_within(0.01).of(25.0)
      expect(result[:xmax]).to be_within(0.01).of(-83.0)
      expect(result[:ymax]).to be_within(0.01).of(37.0)
    end

    it "applies 100% buffer (doubles extent)" do
      result = described_class.apply_buffer(extent, 100.0)

      # Original extent: width=8.0, height=6.0
      # 100% buffer: buffer_x=8.0, buffer_y=6.0
      expect(result[:xmin]).to be_within(0.01).of(-103.0)
      expect(result[:ymin]).to be_within(0.01).of(22.0)
      expect(result[:xmax]).to be_within(0.01).of(-79.0)
      expect(result[:ymax]).to be_within(0.01).of(40.0)
    end
  end

  describe ".format" do
    it "formats extent as comma-separated string" do
      extent = {xmin: -95.0, ymin: 28.0, xmax: -87.7, ymax: 33.8}
      expect(described_class.format(extent)).to eq("-95.0,28.0,-87.7,33.8")
    end

    it "formats extent with integer values" do
      extent = {xmin: -95, ymin: 28, xmax: -88, ymax: 34}
      expect(described_class.format(extent)).to eq("-95,28,-88,34")
    end
  end

  describe ".directory_name" do
    it "generates directory name with rounded coordinates" do
      extent = {xmin: -95.3, ymin: 28.7, xmax: -87.2, ymax: 33.6}
      result = described_class.directory_name("10", extent)
      expect(result).to eq("ne-10m--95-29--87-34")
    end

    it "generates directory name for different scales" do
      extent = {xmin: -95.0, ymin: 28.0, xmax: -88.0, ymax: 32.0}

      expect(described_class.directory_name("10", extent)).to eq("ne-10m--95-28--88-32")
      expect(described_class.directory_name("50", extent)).to eq("ne-50m--95-28--88-32")
      expect(described_class.directory_name("110", extent)).to eq("ne-110m--95-28--88-32")
    end

    it "rounds negative coordinates correctly" do
      extent = {xmin: -95.6, ymin: 28.4, xmax: -87.5, ymax: 33.5}
      result = described_class.directory_name("10", extent)
      expect(result).to eq("ne-10m--96-28--88-34")
    end

    it "avoids dots in directory name" do
      extent = {xmin: -95.7, ymin: 28.3, xmax: -87.8, ymax: 33.9}
      result = described_class.directory_name("110", extent)
      expect(result).not_to include(".")
    end
  end

  describe ".find_available_directory" do
    let(:extent) { {xmin: -95.0, ymin: 28.0, xmax: -88.0, ymax: 32.0} }
    let(:base_name) { "ne-110m--95-28--88-32" }

    after do
      # Clean up any test directories
      [base_name, "#{base_name}-1", "#{base_name}-2", "#{base_name}-3"].each do |dir|
        Dir.rmdir(dir) if Dir.exist?(dir)
      end
    end

    it "returns base name when directory does not exist" do
      result = described_class.find_available_directory("110", extent)
      expect(result).to eq(base_name)
    end

    it "returns base name with -1 when base exists" do
      Dir.mkdir(base_name)

      result = described_class.find_available_directory("110", extent)
      expect(result).to eq("#{base_name}-1")
    end

    it "returns base name with -2 when base and -1 exist" do
      Dir.mkdir(base_name)
      Dir.mkdir("#{base_name}-1")

      result = described_class.find_available_directory("110", extent)
      expect(result).to eq("#{base_name}-2")
    end

    it "finds next available sequence number" do
      Dir.mkdir(base_name)
      Dir.mkdir("#{base_name}-1")
      Dir.mkdir("#{base_name}-2")

      result = described_class.find_available_directory("110", extent)
      expect(result).to eq("#{base_name}-3")
    end

    it "works with different scales" do
      extent_10 = {xmin: -95.0, ymin: 28.0, xmax: -88.0, ymax: 32.0}
      base_10 = "ne-10m--95-28--88-32"

      Dir.mkdir(base_10)

      result = described_class.find_available_directory("10", extent_10)
      expect(result).to eq("#{base_10}-1")

      Dir.rmdir(base_10)
    end
  end
end
