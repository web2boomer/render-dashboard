# frozen_string_literal: true

require "httparty"
require "json"

module RenderDashboard
  class Client
    BASE_URL = "https://api.render.com/v1"
    CACHE_TTL = 300 # 5 minutes

    def initialize(api_key: nil)
      @api_key = api_key || RenderDashboard.configuration.api_key
      raise ArgumentError, "Render API key is required" unless @api_key
    end

    # ── Services ──────────────────────────────────────────────

    def services(limit: 50)
      cache_fetch(:services) do
        get("/services", limit: limit).map { |s| s["service"] || s }
      end
    end

    def service(service_id)
      get("/services/#{service_id}")
    end

    def projects(limit: 50)
      cache_fetch(:projects) do
        get("/projects", limit: limit).map { |p| p["project"] || p }
      end
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

    MAX_RETRIES = 5
    RATE_LIMIT_MUTEX = Mutex.new
    @rate_limit = { remaining: nil, reset_at: nil }

    def self.rate_limit
      @rate_limit
    end

    def get(path, **params)
      retries = 0

      begin
        wait_for_rate_limit

        response = HTTParty.get(
          "#{BASE_URL}#{path}",
          headers: headers,
          query: params.empty? ? nil : params,
          open_timeout: 5,
          read_timeout: 10
        )

        track_rate_limit(response)

        unless response.success?
          if response.code == 429
            reset = (response.headers["ratelimit-reset"] || 60).to_i
            error = RateLimitError.new("Rate limit exceeded on #{path} (resets in #{reset}s)")
            error.define_singleton_method(:reset_seconds) { reset }
            raise error
          end
          raise Error, "Render API error #{response.code} on #{path}: #{response.body}"
        end

        response.parsed_response
      rescue RateLimitError
        raise
      rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ETIMEDOUT => e
        if retries < MAX_RETRIES
          retries += 1
          sleep jitter(0.5 * (2**retries))
          retry
        end
        raise TimeoutError, "Timeout on #{path} after #{retries} retries: #{e.message}"
      end
    end

    def wait_for_rate_limit
      rl = self.class.rate_limit
      return unless rl[:remaining]&.zero? && rl[:reset_at]

      wait = (rl[:reset_at] - Time.now.to_f).ceil
      if wait > 0
        error = RateLimitError.new("Rate limited (resets in #{wait}s)")
        error.define_singleton_method(:reset_seconds) { wait }
        raise error
      end
    end

    def track_rate_limit(response)
      remaining = response.headers["ratelimit-remaining"]
      reset     = response.headers["ratelimit-reset"]
      return unless remaining

      RATE_LIMIT_MUTEX.synchronize do
        self.class.rate_limit[:remaining] = remaining.to_i
        self.class.rate_limit[:reset_at]  = Time.now.to_f + reset.to_i if reset
      end
    end

    def rate_limit_wait
      rl = self.class.rate_limit
      return 0 unless rl[:reset_at]

      [rl[:reset_at] - Time.now.to_f, 0].max
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

    CACHE_MUTEX = Mutex.new
    @cache = {}

    def self.cache
      @cache
    end

    def cache_fetch(key, ttl: CACHE_TTL)
      entry = self.class.cache[key]
      return entry[:data] if entry && (Time.now - entry[:at]) < ttl

      data = yield
      CACHE_MUTEX.synchronize { self.class.cache[key] = { data: data, at: Time.now } }
      data
    end
  end
end
