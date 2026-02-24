# frozen_string_literal: true

module RenderDashboard
  class Engine < ::Rails::Engine
    initializer "render-dashboard.append_routes", after: "action_dispatch.prepare_dispatcher" do |app|
      app.routes.append do
        scope "/render" do
          get "metrics",      to: "render_dashboard/metrics#index",  as: :render_metrics
          get "metrics/data", to: "render_dashboard/metrics#data",   as: :render_metrics_data
        end
      end
    end

    rake_tasks do
      load File.expand_path("../tasks/render-dashboard.rake", __dir__)
    end
  end
end
