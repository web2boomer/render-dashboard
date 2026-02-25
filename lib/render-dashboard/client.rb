# frozen_string_literal: true

require "httparty"
require "json"

module RenderDashboard
  class Client
    BASE_URL = "https://api.render.com/v1"

    def initialize(api_key: nil)
      @api_key = api_key || RenderDashboard.configuration.api_key
      raise ArgumentError, "Render API key is required" unless @api_key
    end

    # ── Services ──────────────────────────────────────────────

    def services(limit: 50)
      get("/services", limit: limit).map { |s| s["service"] || s }
    end

    def service(service_id)
      get("/services/#{service_id}")
    end

    def projects(limit: 50)
      get("/projects", limit: limit).map { |p| p["project"] || p }
    end

    # ── Metrics ───────────────────────────────────────────────

    def cpu(**opts)
      metric("/metrics/cpu", **opts)
    end

    def cpu_limit(**opts)
      metric("/metrics/cpu-limit", **opts)
    end

    def cpu_target(**opts)
      metric("/metrics/cpu-target", **opts)
    end

    def memory(**opts)
      metric("/metrics/memory", **opts)
    end

    def memory_limit(**opts)
      metric("/metrics/memory-limit", **opts)
    end

    def memory_target(**opts)
      metric("/metrics/memory-target", **opts)
    end

    def disk_usage(**opts)
      metric("/metrics/disk-usage", **opts)
    end

    def disk_capacity(**opts)
      metric("/metrics/disk-capacity", **opts)
    end

    def bandwidth(**opts)
      metric("/metrics/bandwidth", **opts)
    end

    def bandwidth_sources(**opts)
      metric("/metrics/bandwidth-sources", **opts)
    end

    def http_requests(**opts)
      metric("/metrics/http-requests", **opts)
    end

    def http_latency(**opts)
      metric("/metrics/http-latency", **opts)
    end

    def active_connections(**opts)
      metric("/metrics/active-connections", **opts)
    end

    def instance_count(**opts)
      metric("/metrics/instance-count", **opts)
    end

    def replication_lag(**opts)
      metric("/metrics/replication-lag", **opts)
    end

    private

    def metric(path, resource: nil, start_time: nil, end_time: nil,
               resolution: nil, instance: nil, aggregation: nil)
      params = {}
      params[:resource]            = resource          if resource
      params[:startTime]           = format_time(start_time) if start_time
      params[:endTime]             = format_time(end_time)   if end_time
      params[:resolutionSeconds]   = resolution        if resolution
      params[:instance]            = instance          if instance
      params[:aggregationMethod]   = aggregation       if aggregation
      get(path, **params)
    end

    MAX_RETRIES = 3
    BASE_DELAY  = 2.0 # seconds

    def get(path, **params)
      retries = 0

      begin
        response = HTTParty.get(
          "#{BASE_URL}#{path}",
          headers: headers,
          query: params.empty? ? nil : params,
          timeout: 30
        )

        unless response.success?
          raise RateLimitError, "Rate limit exceeded on #{path}" if response.code == 429
          raise Error, "Render API error #{response.code} on #{path}: #{response.body}"
        end

        response.parsed_response
      rescue RateLimitError
        if retries < MAX_RETRIES
          retries += 1
          sleep jitter(BASE_DELAY * (2**retries))
          retry
        end
        raise RateLimitError, "Rate limit exceeded on #{path}. Retried #{retries}x."
      rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ETIMEDOUT => e
        if retries < MAX_RETRIES
          retries += 1
          sleep jitter(BASE_DELAY * (2**retries))
          retry
        end
        raise TimeoutError, "Timeout on #{path} after #{retries} retries: #{e.message}"
      end
    end

    def jitter(base)
      base * (0.5 + rand)
    end

    def headers
      {
        "Accept" => "application/json",
        "Authorization" => "Bearer #{@api_key}"
      }
    end

    def format_time(time)
      case time
      when String then time
      when Numeric then Time.at(time).utc.iso8601
      else time.utc.iso8601
      end
    end
  end
end
