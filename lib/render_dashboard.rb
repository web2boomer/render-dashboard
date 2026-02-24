# frozen_string_literal: true

require_relative "render_dashboard/version"
require_relative "render_dashboard/configuration"
require_relative "render_dashboard/client"

module RenderDashboard
  class Error < StandardError; end
end

require_relative "render_dashboard/engine" if defined?(Rails)
