module Cloudflare
  module Rails
    class Railtie < ::Rails::Railtie
      # patch rack::request::helpers to use our cloudflare ips - this way request.ip is
      # correct inside of rack and rails
      module CheckTrustedProxies
        def trusted_proxy?(ip)
          ::Rails.application.config.cloudflare.ips.any? { |proxy| proxy === ip } || super
        end
      end

      Rack::Request::Helpers.prepend CheckTrustedProxies

      # rack-attack Rack::Request before the above is run, so if rack-attack is loaded we need to
      # prepend our module there as well, see:
      # https://github.com/kickstarter/rack-attack/blob/4fc4d79c9d2697ec21263109af23f11ea93a23ce/lib/rack/attack/request.rb
      if defined? Rack::Attack::Request
        Rack::Attack::Request.prepend CheckTrustedProxies
      end

      # patch ActionDispatch::RemoteIP to use our cloudflare ips - this way
      # request.remote_ip is correct inside of rails
      module RemoteIpProxies
        def proxies
          super + ::Rails.application.config.cloudflare.ips
        end
      end

      ActionDispatch::RemoteIp.prepend RemoteIpProxies

      class Importer

        IPS_V4 = %W(
          173.245.48.0/20
          103.21.244.0/22
          103.22.200.0/22
          103.31.4.0/22
          141.101.64.0/18
          108.162.192.0/18
          190.93.240.0/20
          188.114.96.0/20
          197.234.240.0/22
          198.41.128.0/17
          162.158.0.0/15
          104.16.0.0/12
          172.64.0.0/13
          131.0.72.0/22
        ).freeze

        IPS_V6 = %w(
          2400:cb00::/32
          2606:4700::/32
          2803:f800::/32
          2405:b500::/32
          2405:8100::/32
          2a06:98c0::/29
          2c0f:f248::/32
        ).freeze


        def self.import
          IPS_V4 + IPS_V6
        end
      end

      # setup defaults before we configure our app.
      DEFAULTS = {
        ips: [],
      }.freeze

      config.before_configuration do |app|
        app.config.cloudflare = ActiveSupport::OrderedOptions.new
        app.config.cloudflare.reverse_merge! DEFAULTS
      end

      # we set config.cloudflare.ips after_initialize so that our cache will
      # be correctly setup. we rescue and log errors so that failures won't prevent
      # rails from booting
      config.after_initialize do |app|
        ::Rails.application.config.cloudflare.ips += Importer.import
      end
    end
  end
end
