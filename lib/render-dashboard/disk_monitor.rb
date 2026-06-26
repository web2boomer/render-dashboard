# frozen_string_literal: true

module RenderDashboard
  module DiskMonitor
    module_function

    def check(
      service_id: ENV["RENDER_SERVICE_ID"],
      threshold: default_threshold,
      on_info: method(:default_info),
      on_warn: method(:default_warn),
      on_urgent: method(:default_urgent),
      alert: true
    )
      unless RenderDashboard.configuration.api_key && service_id
        on_warn.call "Disk check skipped: set RENDER_API_KEY + RENDER_SERVICE_ID"
        return nil
      end

      usage = DiskUsage.fetch(service_id)
      on_info.call "Disk usage: #{usage.summary}"

      if usage.over_threshold?(threshold)
        on_urgent.call "Disk alert: #{usage.service_name} at #{usage.used_percent}% (threshold: #{threshold}%)"
        deliver_alerts(usage, threshold) if alert
      end

      usage
    rescue Error => e
      on_warn.call "Disk check failed: #{e.message}"
      nil
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

    def deliver_alerts(usage, threshold)
      if defined?(SystemMailer) && SystemMailer.respond_to?(:disk_alert)
        SystemMailer.disk_alert(
          used_percent: usage.used_percent,
          used_gb: usage.used_gb,
          total_gb: usage.total_gb,
          service_name: usage.service_name
        ).deliver_later
      end

      if defined?(WhatsappNotifier) && WhatsappNotifier.respond_to?(:send_system_alert)
        WhatsappNotifier.send_system_alert(
          "Disk at #{usage.used_percent}% on #{usage.service_name}",
          "#{usage.used_gb} GB / #{usage.total_gb} GB used. Consider cleaning up or expanding storage."
        )
      end
    end

    private_class_method :deliver_alerts
  end
end
