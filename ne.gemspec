require_relative "lib/natural_earth/version"

Gem::Specification.new do |spec|
  spec.name = "ne"
  spec.version = NaturalEarth::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Extract vector basemap data from the Natural Earth dataset"
  spec.description = "A command-line tool that wraps ogr2ogr to quickly extract relevant data from Natural Earth in shapefile format"
  spec.homepage = "https://github.com/yourusername/ne"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "bin/*", "README.md", "LICENSE", "AGENTS.md", "CLAUDE.md"]
  spec.bindir = "bin"
  spec.executables = ["ne"]
  spec.require_paths = ["lib"]

  spec.add_dependency "dry-cli", "~> 1.0"
  spec.add_dependency "rainbow", "~> 3.1"
  spec.add_dependency "csv", "~> 3.3"
end
