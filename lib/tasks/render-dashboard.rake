namespace :"render-dashboard" do

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
        puts "Size:    #{disk['sizeGB']} GB (provisioned)"
        puts "Mount:   #{disk['mountPath']}"

        begin
          usage = RenderDashboard::DiskUsage.fetch(svc["id"], client: client, service_name: svc["name"])
          puts "Usage:   #{usage.used_percent}% (#{usage.used_gb} GB / #{usage.total_gb} GB) as of #{usage.timestamp}"
        rescue RenderDashboard::Error => e
          warn "Disk metrics unavailable: #{e.message}"
        end
      else
        puts "Disk:    none attached"
      end
      puts ""
    end
  rescue => e
    warn "render-dashboard:info failed: #{e.message}"
  end


  desc "Check disk usage via Render metrics API and alert if above threshold"
  task disk_check: :environment do
    RenderDashboard::DiskMonitor.check(
      on_info: ->(message) { defined?(Log) && Log.respond_to?(:info) ? Log.info(message) : puts(message) },
      on_warn: ->(message) { defined?(Log) && Log.respond_to?(:warn) ? Log.warn(message) : warn(message) },
      on_urgent: ->(message) { defined?(Log) && Log.respond_to?(:urgent) ? Log.urgent(message) : warn(message) }
    )
  end

end
