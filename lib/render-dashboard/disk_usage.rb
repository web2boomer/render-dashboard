# frozen_string_literal: true

module RenderDashboard
  class DiskUsage
    BYTES_PER_GB = 1_000_000_000.0

    attr_reader :used_bytes, :capacity_bytes, :used_gb, :total_gb, :used_percent,
                :timestamp, :source, :service_name, :resource_id

    def self.fetch(resource_id, client: nil, service_name: nil)
      raise ArgumentError, "resource_id is required" if resource_id.to_s.empty?

      client ||= Client.new
      service_name ||= service_name_for(client, resource_id)

      usage_series = client.disk_usage(resource: resource_id)
      capacity_series = client.disk_capacity(resource: resource_id)

      used_bytes = latest_metric_value(usage_series)
      capacity_bytes = latest_metric_value(capacity_series)
      timestamp = latest_metric_timestamp(usage_series) || latest_metric_timestamp(capacity_series)

      raise MetricsUnavailableError.new(resource_id: resource_id, metric: "disk usage") unless used_bytes
      raise MetricsUnavailableError.new(resource_id: resource_id, metric: "disk capacity") unless capacity_bytes

      new(
        used_bytes: used_bytes,
        capacity_bytes: capacity_bytes,
        timestamp: timestamp,
        service_name: service_name,
        resource_id: resource_id,
        source: "Render metrics API"
      )
    end

    def initialize(used_bytes:, capacity_bytes:, timestamp:, service_name:, resource_id:, source:)
      @used_bytes = used_bytes.to_f
      @capacity_bytes = capacity_bytes.to_f
      @used_gb = (@used_bytes / BYTES_PER_GB).round(2)
      @total_gb = (@capacity_bytes / BYTES_PER_GB).round(2)
      @used_percent = (@used_bytes / @capacity_bytes * 100).round(1)
      @timestamp = timestamp
      @service_name = service_name
      @resource_id = resource_id
      @source = source
    end

    def over_threshold?(threshold)
      used_percent >= threshold
    end

    def summary
      "#{used_percent}% (#{used_gb} GB / #{total_gb} GB) on #{service_name} (#{source})"
    end

    def self.latest_metric_value(series)
      point = latest_metric_point(series)
      point && point["value"]
    end

    def self.latest_metric_timestamp(series)
      point = latest_metric_point(series)
      point && point["timestamp"]
    end

    def self.latest_metric_point(series)
      return nil unless series.is_a?(Array) && series.any?

      values = series.flat_map { |entry| entry["values"] || [] }
      return nil if values.empty?

      values.max_by { |point| point["timestamp"].to_s }
    end

    def self.service_name_for(client, resource_id)
      client.service(resource_id)["name"]
    rescue Error
      ENV.fetch("RENDER_SERVICE_NAME", "database")
    end

    private_class_method :latest_metric_point, :service_name_for
  end
end
