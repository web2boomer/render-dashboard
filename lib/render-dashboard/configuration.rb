# frozen_string_literal: true

module RenderDashboard
  class Configuration
    attr_accessor :api_key

    def initialize
      @api_key = ENV["RENDER_API_KEY"]
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
