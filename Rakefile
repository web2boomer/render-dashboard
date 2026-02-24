# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Install git hooks"
task :setup do
  system "git config core.hooksPath .githooks"
  puts "Git hooks installed (.githooks/)"
end

task default: :spec
