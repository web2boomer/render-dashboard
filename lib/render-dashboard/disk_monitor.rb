# frozen_string_literal: true

module RenderDashboard
  module DiskMonitor
    module_function

    def check(
      service_id: ENV["RENDER_SERVICE_ID"],
      threshold: default_threshold,
      on_info: method(:default_info),
      on_warn: method(:default_warn),
      on_urgent: method(:default_urgent)
    )
      unless RenderDashboard.configuration.api_key && service_id
        on_warn.call "Disk check skipped: set RENDER_API_KEY + RENDER_SERVICE_ID"
        return nil
      end

      usage = DiskUsage.fetch(service_id)
      on_info.call "Disk usage: #{usage.summary}"

      if usage.over_threshold?(threshold)
        on_urgent.call "Disk alert: #{usage.service_name} at #{usage.used_percent}% (threshold: #{threshold}%). #{usage.used_gb} GB / #{usage.total_gb} GB used."
      end

      usage
    rescue Error => e
      on_warn.call failure_message(e)
      nil
    end

    def failure_message(error)
      category = case error
                 when RateLimitError then "rate limited"
                 when TimeoutError then "API timeout"
                 when ApiError then error.category
                 when MetricsUnavailableError then "no metrics"
                 end

      if category
        "Disk check failed (#{category}): #{error.message}"
      else
        "Disk check failed: #{error.message}"
      end
    end

    def default_threshold
      (ENV["RENDER_DISK_PERCENT_USE_WARNING"] || ENV["DISK_ALERT_THRESHOLD"] || 80).to_i
    end

    def default_info(message)
      puts message
    end

    def default_warn(message)
      warn message
    end

    def default_urgent(message)
      warn message
    end
  end
end
