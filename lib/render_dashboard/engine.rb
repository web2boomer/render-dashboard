# frozen_string_literal: true

module RenderDashboard
  class Engine < ::Rails::Engine
    isolate_namespace RenderDashboard

    initializer "render_dashboard.assets" do |app|
      # Engine views are automatically available via isolate_namespace
    end

    rake_tasks do
      load File.expand_path("../../tasks/render_dashboard.rake", __dir__)
    end
  end
end
