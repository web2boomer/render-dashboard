# frozen_string_literal: true

require "json"

require_relative "render-dashboard/version"
require_relative "render-dashboard/configuration"
require_relative "render-dashboard/client"
require_relative "render-dashboard/disk_usage"
require_relative "render-dashboard/disk_monitor"

module RenderDashboard
  class Error < StandardError; end
  class RateLimitError < Error; end
  class TimeoutError < Error; end

  class ApiError < Error
    attr_reader :status, :path, :body, :category

    def initialize(status:, path:, body: nil)
      @status = status.to_i
      @path = path
      @body = body
      @category = categorize
      super(build_message)
    end

    private

    def categorize
      case status
      when 401, 403 then "authentication"
      when 404 then "not found"
      when 429 then "rate limited"
      when 500..599 then "server error"
      else "API error"
      end
    end

    def build_message
      reason = case category
               when "authentication" then "invalid or unauthorized API key"
               when "not found" then "resource not found or not accessible"
               when "rate limited" then "rate limit exceeded"
               when "server error" then "Render server error"
               else "HTTP #{status}"
               end

      message = "#{reason} (#{path})"
      detail = parsed_body_detail
      message += " — #{detail}" if detail
      message
    end

    def parsed_body_detail
      return nil if body.to_s.strip.empty?

      parsed = JSON.parse(body)
      parsed["message"] || parsed["error"] || body.to_s.strip
    rescue JSON::ParserError
      body.to_s.strip[0, 200]
    end
  end

  class MetricsUnavailableError < Error
    attr_reader :resource_id, :metric

    def initialize(resource_id:, metric:)
      @resource_id = resource_id
      @metric = metric
      super(build_message)
    end

    private

    def build_message
      hint = "the service may have no persistent disk, or metrics are not yet available"
      "no #{metric} data for #{resource_id} — #{hint}"
    end
  end
end

require_relative "render-dashboard/engine" if defined?(Rails)
