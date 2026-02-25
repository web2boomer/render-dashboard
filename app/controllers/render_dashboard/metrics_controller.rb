# frozen_string_literal: true

module RenderDashboard
  class MetricsController < ::ApplicationController
    def index
      all_services = client.services
      projects = client.projects rescue []

      env_to_project = {}
      projects.each do |proj|
        name = proj["name"] || "Unnamed Project"
        (proj["environmentIds"] || []).each { |eid| env_to_project[eid] = name }
      end

      grouped = all_services
        .sort_by { |s| (s["name"] || "").downcase }
        .group_by { |s| env_to_project[s["environmentId"]] || "Other" }

      @grouped_services = grouped.sort_by { |name, _| name == "Other" ? "\xFF" : name.downcase }
      @services = all_services
    rescue RenderDashboard::Error, ArgumentError => e
      @error = e.message
      @services = []
      @grouped_services = []
    end

    def data
      resource = params[:resource]
      hours    = (params[:hours] || 1).to_f
      end_time   = Time.current
      start_time = end_time - hours.hours

      resolution = resolution_for(hours)

      common_opts = { resource: resource, start_time: start_time, end_time: end_time, resolution: resolution }

      cpu_data          = safe_metric(:cpu, **common_opts)
      memory_data       = safe_metric(:memory, **common_opts)
      cpu_limit_data    = safe_metric(:cpu_limit, **common_opts)
      memory_limit_data = safe_metric(:memory_limit, **common_opts)
      disk_usage_data     = safe_metric(:disk_usage, **common_opts)
      disk_capacity_data  = safe_metric(:disk_capacity, **common_opts)

      payload = {
        cpu:          cpu_data,
        memory:       memory_data,
        cpu_limit:    cpu_limit_data,
        memory_limit: memory_limit_data
      }

      if disk_usage_data.present?
        payload[:disk_usage]    = disk_usage_data
        payload[:disk_capacity] = disk_capacity_data
      end

      render json: payload
    rescue RenderDashboard::RateLimitError => e
      render json: { error: e.message, rate_limited: true }, status: :too_many_requests
    rescue RenderDashboard::TimeoutError => e
      render json: { error: e.message, timed_out: true }, status: :gateway_timeout
    rescue RenderDashboard::Error, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def client
      @client ||= RenderDashboard::Client.new
    end

    def safe_metric(method, **opts)
      client.public_send(method, **opts)
    rescue RenderDashboard::RateLimitError, RenderDashboard::TimeoutError
      raise
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
