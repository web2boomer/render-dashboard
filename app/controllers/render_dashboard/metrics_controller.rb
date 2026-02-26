# frozen_string_literal: true

module RenderDashboard
  class MetricsController < ::ApplicationController
    def index
      services_thread = Thread.new { client.services }
      projects_thread = Thread.new { client.projects rescue [] }
      all_services = services_thread.value
      projects = projects_thread.value

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
      pinned = (params[:pin] || "").split(",").select(&:present?)
      if pinned.any?
        @error = nil
        @services = pinned.map { |id| { "id" => id, "name" => id, "type" => "", "serviceDetails" => {} } }
        @grouped_services = [["Pinned", @services]]
      else
        @error = e.message
        @services = []
        @grouped_services = []
      end
    end

    def data
      resource = params[:resource]
      hours    = (params[:hours] || 1).to_f
      end_time   = Time.current
      start_time = end_time - hours.hours

      resolution = resolution_for(hours)

      common_opts = { resource: resource, start_time: start_time, end_time: end_time, resolution: resolution }

      metrics = %i[cpu memory cpu_limit memory_limit disk_usage disk_capacity]
      results = fetch_metrics_parallel(metrics, common_opts)

      payload = {
        cpu:          results[:cpu],
        memory:       results[:memory],
        cpu_limit:    results[:cpu_limit],
        memory_limit: results[:memory_limit]
      }

      if results[:disk_usage].present?
        payload[:disk_usage]    = results[:disk_usage]
        payload[:disk_capacity] = results[:disk_capacity]
      end

      render json: payload
    rescue RenderDashboard::RateLimitError => e
      retry_after = e.respond_to?(:reset_seconds) ? e.reset_seconds : 60
      response.set_header("Retry-After", retry_after.to_s)
      render json: { error: e.message, rate_limited: true, retry_after: retry_after }, status: :too_many_requests
    rescue RenderDashboard::TimeoutError => e
      render json: { error: e.message, timed_out: true }, status: :gateway_timeout
    rescue RenderDashboard::Error, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def client
      @client ||= RenderDashboard::Client.new
    end

    def fetch_metrics_parallel(metrics, opts)
      threads = metrics.map do |metric|
        Thread.new(metric) { |m| [m, safe_metric(m, **opts)] }
      end
      results = {}
      error = nil
      threads.each do |t|
        begin
          key, value = t.value
          results[key] = value
        rescue RenderDashboard::RateLimitError, RenderDashboard::TimeoutError => e
          error ||= e
        end
      end
      raise error if error
      results
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
