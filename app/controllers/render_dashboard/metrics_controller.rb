# frozen_string_literal: true

module RenderDashboard
  class MetricsController < ::ApplicationController
    def index
      @services = client.services
    rescue RenderDashboard::Error, ArgumentError => e
      @error = e.message
      @services = []
    end

    def data
      resource = params[:resource]
      hours    = (params[:hours] || 1).to_f
      end_time   = Time.current
      start_time = end_time - hours.hours

      resolution = resolution_for(hours)

      cpu_data    = client.cpu(resource: resource, start_time: start_time, end_time: end_time, resolution: resolution)
      memory_data = client.memory(resource: resource, start_time: start_time, end_time: end_time, resolution: resolution)
      cpu_limit_data    = safe_metric(:cpu_limit, resource: resource, start_time: start_time, end_time: end_time, resolution: resolution)
      memory_limit_data = safe_metric(:memory_limit, resource: resource, start_time: start_time, end_time: end_time, resolution: resolution)

      render json: {
        cpu:          cpu_data,
        memory:       memory_data,
        cpu_limit:    cpu_limit_data,
        memory_limit: memory_limit_data
      }
    rescue RenderDashboard::Error, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def client
      @client ||= RenderDashboard::Client.new
    end

    def safe_metric(method, **opts)
      client.public_send(method, **opts)
    rescue RenderDashboard::Error
      []
    end

    def resolution_for(hours)
      case hours
      when 0..1    then 60
      when 1..6    then 120
      when 6..24   then 300
      when 24..168 then 900
      else              3600
      end
    end
  end
end
