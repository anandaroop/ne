require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Run StandardRB linter"
task :lint do
  sh "bundle exec standardrb"
end

desc "Auto-fix StandardRB issues"
task :fix do
  sh "bundle exec standardrb --fix"
end

desc "Run tests and linter"
task default: [:spec, :lint]
