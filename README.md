# RenderDashboard

A Ruby gem providing a Render.com API client, mountable Rails metrics dashboard, and monitoring rake tasks.

## Installation

Add to your Gemfile:

```ruby
gem 'render_dashboard', path: '/path/to/render_dashboard'
# or
gem 'render_dashboard', github: 'your-org/render_dashboard', branch: 'main'
```

## Configuration

Create an initializer (e.g. `config/initializers/render_dashboard.rb`):

```ruby
RenderDashboard.configure do |config|
  config.api_key = ENV['RENDER_API_KEY']
end
```

## Mounting the Dashboard

In `config/routes.rb`:

```ruby
mount RenderDashboard::Engine, at: "/render"
```

This serves the metrics dashboard at `/render/metrics`.

## API Client

Use the client directly for custom integrations:

```ruby
client = RenderDashboard::Client.new

# List all services
client.services

# Get CPU metrics for a service (last hour by default)
client.cpu(resource: "srv-xxxxx")

# Get memory metrics with custom time range
client.memory(
  resource: "srv-xxxxx",
  start_time: 6.hours.ago,
  end_time: Time.current,
  resolution: 300
)
```

### Available Metric Methods

All metric methods accept: `resource:`, `start_time:`, `end_time:`, `resolution:`, `instance:`, `aggregation:`

| Method | Render Endpoint |
|--------|----------------|
| `cpu` | `/metrics/cpu` |
| `cpu_limit` | `/metrics/cpu-limit` |
| `memory` | `/metrics/memory` |
| `memory_limit` | `/metrics/memory-limit` |
| `disk_usage` | `/metrics/disk-usage` |
| `disk_capacity` | `/metrics/disk-capacity` |
| `bandwidth` | `/metrics/bandwidth` |
| `http_requests` | `/metrics/http-requests` |
| `http_latency` | `/metrics/http-latency` |
| `active_connections` | `/metrics/active-connections` |
| `instance_count` | `/metrics/instance-count` |

## Rake Tasks

Available when the gem is loaded in a Rails app:

```bash
# Show service and disk info
rake render_dashboard:info

# Check disk usage against threshold (default 80%)
rake render_dashboard:disk_check

# Override threshold
DISK_ALERT_THRESHOLD=90 rake render_dashboard:disk_check
```
