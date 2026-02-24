# frozen_string_literal: true

require_relative "lib/render_dashboard/version"

Gem::Specification.new do |spec|
  spec.name = "render_dashboard"
  spec.version = RenderDashboard::VERSION
  spec.authors = ["Alex O'Byrne"]
  spec.email = ["alex@aob.io"]

  spec.summary = "Render.com API client, metrics dashboard engine, and monitoring rake tasks"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,lib}/**/*", "README.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "httparty", ">= 0.20"
  spec.add_dependency "railties", ">= 6.0"
end
