namespace :render_dashboard do

  desc "Show Render service and disk info for all services (or set RENDER_SERVICE_ID for one)"
  task info: :environment do
    client = RenderDashboard::Client.new

    service_id = ENV["RENDER_SERVICE_ID"] || ENV["service_id"]

    services = if service_id
                 [client.service(service_id)]
               else
                 client.services
               end

    services.each do |svc|
      details = svc["serviceDetails"] || {}
      disk    = details["disk"]

      puts ""
      puts "Service: #{svc['name']} (#{svc['id']})"
      puts "Type:    #{svc['type']} / #{details['env']}"
      puts "Plan:    #{details['plan']}"
      puts "Region:  #{details['region']}"
      puts "Status:  #{svc['suspended'] == 'not_suspended' ? 'active' : svc['suspended']}"

      if disk
        puts "Disk:    #{disk['name']} (#{disk['id']})"
        puts "Size:    #{disk['sizeGB']} GB"
        puts "Mount:   #{disk['mountPath']}"
      else
        puts "Disk:    none attached"
      end
      puts ""
    end
  rescue => e
    warn "render_dashboard:info failed: #{e.message}"
  end


  desc "Check database disk usage and alert if above threshold"
  task disk_check: :environment do
    threshold    = (ENV["DISK_ALERT_THRESHOLD"] || 80).to_i
    service_id   = ENV["RENDER_SERVICE_ID"]
    disk_size_gb = nil
    service_name = nil

    if RenderDashboard.configuration.api_key && service_id
      begin
        client = RenderDashboard::Client.new
        data   = client.service(service_id)
        service_name = data["name"]
        disk_size_gb = data.dig("serviceDetails", "disk", "sizeGB")
      rescue => e
        warn "Render API call failed: #{e.message}"
      end
    end

    disk_size_gb ||= ENV["RENDER_DISK_SIZE_GB"]&.to_f
    service_name ||= ENV.fetch("RENDER_SERVICE_NAME", "database")

    unless disk_size_gb
      warn "Disk check skipped: set RENDER_API_KEY + RENDER_SERVICE_ID, or RENDER_DISK_SIZE_GB"
      next
    end

    db_size_mb = ActiveRecord::Base.connection.select_value(<<~SQL).to_f
      SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1)
      FROM information_schema.tables
      WHERE table_schema = DATABASE()
    SQL

    used_gb      = (db_size_mb / 1024).round(2)
    total_gb     = disk_size_gb.to_f
    used_percent = (used_gb / total_gb * 100).round(1)

    puts "Disk usage: #{used_percent}% (#{used_gb} GB / #{total_gb} GB) on #{service_name}"

    if used_percent >= threshold
      puts "ALERT: #{service_name} at #{used_percent}% (threshold: #{threshold}%)"

      # Hook into host app alerting if available
      if defined?(SystemMailer) && SystemMailer.respond_to?(:disk_alert)
        SystemMailer.disk_alert(
          used_percent: used_percent,
          used_gb: used_gb,
          total_gb: total_gb,
          service_name: service_name
        ).deliver_later
      end

      if defined?(WhatsappNotifier) && WhatsappNotifier.respond_to?(:send_system_alert)
        WhatsappNotifier.send_system_alert(
          "Disk at #{used_percent}% on #{service_name}",
          "#{used_gb} GB / #{total_gb} GB used. Consider cleaning up or expanding storage."
        )
      end
    end
  rescue => e
    warn "render_dashboard:disk_check failed: #{e.message}"
  end

end
