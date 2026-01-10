require "spec_helper"
require "tempfile"
require_relative "../lib/natural_earth/layer_resolver"

RSpec.describe NaturalEarth::LayerResolver do
  describe ".resolve_layers" do
    it "returns default layers for nil input" do
      result = described_class.resolve_layers(nil)
      expect(result).to eq(described_class::DEFAULT_LAYERS)
    end

    it "returns default layers for empty string" do
      result = described_class.resolve_layers("")
      expect(result).to eq(described_class::DEFAULT_LAYERS)
    end

    it "returns a copy of default layers (not the original array)" do
      result = described_class.resolve_layers(nil)
      expect(result).not_to equal(described_class::DEFAULT_LAYERS)
    end

    it "parses custom layer list" do
      result = described_class.resolve_layers("land,lakes,coastline")
      expect(result).to eq(["land", "lakes", "coastline"])
    end

    it "handles whitespace in layer list" do
      result = described_class.resolve_layers("land, lakes, coastline")
      expect(result).to eq(["land", "lakes", "coastline"])
    end

    it "filters out empty entries" do
      result = described_class.resolve_layers("land,,lakes")
      expect(result).to eq(["land", "lakes"])
    end

    it "returns default + extras when 'default' is in list" do
      result = described_class.resolve_layers("default,glaciated_areas,coastline")

      expect(result).to include(*described_class::DEFAULT_LAYERS)
      expect(result).to include("glaciated_areas", "coastline")
      expect(result.size).to eq(described_class::DEFAULT_LAYERS.size + 2)
    end

    it "handles 'default' with whitespace" do
      result = described_class.resolve_layers("default, glaciated_areas")

      expect(result).to include(*described_class::DEFAULT_LAYERS)
      expect(result).to include("glaciated_areas")
    end

    it "handles just 'default'" do
      result = described_class.resolve_layers("default")
      expect(result).to eq(described_class::DEFAULT_LAYERS)
    end
  end

  describe ".build_layer_map" do
    let(:csv_content) do
      <<~CSV
        scale,theme,layer
        10,physical,land
        10,physical,lakes
        10,cultural,admin_0_countries
        50,physical,land
        50,physical,coastline
        110,physical,land
        ne/tools/example.shp
      CSV
    end

    let(:csv_file) do
      file = Tempfile.new(["ne", ".csv"])
      file.write(csv_content)
      file.rewind
      file
    end

    after do
      csv_file.close
      csv_file.unlink
    end

    it "builds layer map for scale 10" do
      result = described_class.build_layer_map(csv_file.path, "10")

      expect(result).to eq({
        "land" => {theme: "physical", scale: "10"},
        "lakes" => {theme: "physical", scale: "10"},
        "admin_0_countries" => {theme: "cultural", scale: "10"}
      })
    end

    it "builds layer map for scale 50" do
      result = described_class.build_layer_map(csv_file.path, "50")

      expect(result).to eq({
        "land" => {theme: "physical", scale: "50"},
        "coastline" => {theme: "physical", scale: "50"}
      })
    end

    it "builds layer map for scale 110" do
      result = described_class.build_layer_map(csv_file.path, "110")

      expect(result).to eq({
        "land" => {theme: "physical", scale: "110"}
      })
    end

    it "skips entries starting with 'ne/'" do
      result = described_class.build_layer_map(csv_file.path, "10")
      expect(result.keys).not_to include("ne/tools/example.shp")
    end

    it "returns empty hash for non-existent file" do
      result = described_class.build_layer_map("/nonexistent/file.csv", "10")
      expect(result).to eq({})
    end
  end

  describe ".filter_available" do
    let(:layer_map) do
      {
        "land" => {theme: "physical", scale: "10"},
        "lakes" => {theme: "physical", scale: "10"},
        "admin_0_countries" => {theme: "cultural", scale: "10"}
      }
    end

    it "filters all available layers" do
      requested = ["land", "lakes"]
      result = described_class.filter_available(requested, layer_map)

      expect(result[:available]).to eq(["land", "lakes"])
      expect(result[:unavailable]).to eq([])
    end

    it "filters mixed available and unavailable layers" do
      requested = ["land", "coastline", "lakes", "ocean"]
      result = described_class.filter_available(requested, layer_map)

      expect(result[:available]).to eq(["land", "lakes"])
      expect(result[:unavailable]).to eq(["coastline", "ocean"])
    end

    it "handles all unavailable layers" do
      requested = ["coastline", "ocean"]
      result = described_class.filter_available(requested, layer_map)

      expect(result[:available]).to eq([])
      expect(result[:unavailable]).to eq(["coastline", "ocean"])
    end

    it "handles empty request list" do
      result = described_class.filter_available([], layer_map)

      expect(result[:available]).to eq([])
      expect(result[:unavailable]).to eq([])
    end

    it "preserves order of requested layers" do
      requested = ["admin_0_countries", "land", "lakes"]
      result = described_class.filter_available(requested, layer_map)

      expect(result[:available]).to eq(["admin_0_countries", "land", "lakes"])
    end
  end
end
