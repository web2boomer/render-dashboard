# frozen_string_literal: true

require_relative "render-dashboard/version"
require_relative "render-dashboard/configuration"
require_relative "render-dashboard/client"
require_relative "render-dashboard/disk_usage"
require_relative "render-dashboard/disk_monitor"

module RenderDashboard
  class Error < StandardError; end
  class RateLimitError < Error; end
  class TimeoutError < Error; end
end

require_relative "render-dashboard/engine" if defined?(Rails)
