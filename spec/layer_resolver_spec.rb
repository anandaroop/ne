require "spec_helper"
require "tempfile"
require_relative "../lib/natural_earth/layer_resolver"

RSpec.describe NaturalEarth::LayerResolver do
  describe ".resolve_layers" do
    let(:layer_map_with_defaults) do
      {
        "land" => {theme: "physical", scale: "10", default: true},
        "lakes" => {theme: "physical", scale: "10", default: true},
        "admin_0_countries" => {theme: "cultural", scale: "10", default: true},
        "coastline" => {theme: "physical", scale: "10", default: false},
        "glaciated_areas" => {theme: "physical", scale: "10", default: false}
      }
    end

    it "returns default layers for nil input" do
      result = described_class.resolve_layers(nil, layer_map_with_defaults)
      expect(result).to contain_exactly("land", "lakes", "admin_0_countries")
    end

    it "returns default layers for empty string" do
      result = described_class.resolve_layers("", layer_map_with_defaults)
      expect(result).to contain_exactly("land", "lakes", "admin_0_countries")
    end

    it "returns a copy of default layers (not the original array)" do
      result1 = described_class.resolve_layers(nil, layer_map_with_defaults)
      result2 = described_class.resolve_layers(nil, layer_map_with_defaults)
      expect(result1).not_to equal(result2)
    end

    it "parses custom layer list" do
      result = described_class.resolve_layers("land,lakes,coastline", layer_map_with_defaults)
      expect(result).to eq(["land", "lakes", "coastline"])
    end

    it "handles whitespace in layer list" do
      result = described_class.resolve_layers("land, lakes, coastline", layer_map_with_defaults)
      expect(result).to eq(["land", "lakes", "coastline"])
    end

    it "filters out empty entries" do
      result = described_class.resolve_layers("land,,lakes", layer_map_with_defaults)
      expect(result).to eq(["land", "lakes"])
    end

    it "returns default + extras when 'default' is in list" do
      result = described_class.resolve_layers("default,glaciated_areas,coastline", layer_map_with_defaults)

      expect(result).to include("land", "lakes", "admin_0_countries")
      expect(result).to include("glaciated_areas", "coastline")
      expect(result.size).to eq(5)
    end

    it "handles 'default' with whitespace" do
      result = described_class.resolve_layers("default, glaciated_areas", layer_map_with_defaults)

      expect(result).to include("land", "lakes", "admin_0_countries")
      expect(result).to include("glaciated_areas")
    end

    it "handles just 'default'" do
      result = described_class.resolve_layers("default", layer_map_with_defaults)
      expect(result).to contain_exactly("land", "lakes", "admin_0_countries")
    end
  end

  describe ".build_layer_map" do
    let(:csv_content) do
      <<~CSV
        scale,theme,layer,default
        10,physical,land,TRUE
        10,physical,lakes,TRUE
        10,cultural,admin_0_countries,TRUE
        50,physical,land,TRUE
        50,physical,coastline,FALSE
        110,physical,land,TRUE
        ne/tools/example.shp,FALSE
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
        "land" => {theme: "physical", scale: "10", default: true},
        "lakes" => {theme: "physical", scale: "10", default: true},
        "admin_0_countries" => {theme: "cultural", scale: "10", default: true}
      })
    end

    it "builds layer map for scale 50" do
      result = described_class.build_layer_map(csv_file.path, "50")

      expect(result).to eq({
        "land" => {theme: "physical", scale: "50", default: true},
        "coastline" => {theme: "physical", scale: "50", default: false}
      })
    end

    it "builds layer map for scale 110" do
      result = described_class.build_layer_map(csv_file.path, "110")

      expect(result).to eq({
        "land" => {theme: "physical", scale: "110", default: true}
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

  describe ".get_default_layers" do
    let(:layer_map) do
      {
        "land" => {theme: "physical", scale: "10", default: true},
        "lakes" => {theme: "physical", scale: "10", default: true},
        "coastline" => {theme: "physical", scale: "10", default: false},
        "admin_0_countries" => {theme: "cultural", scale: "10", default: true}
      }
    end

    it "returns only layers marked as default" do
      result = described_class.get_default_layers(layer_map)
      expect(result).to contain_exactly("land", "lakes", "admin_0_countries")
    end

    it "returns empty array when no defaults exist" do
      no_defaults = {
        "coastline" => {theme: "physical", scale: "10", default: false},
        "ocean" => {theme: "physical", scale: "10", default: false}
      }
      result = described_class.get_default_layers(no_defaults)
      expect(result).to eq([])
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
