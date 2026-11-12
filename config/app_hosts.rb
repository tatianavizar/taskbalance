# The host names production answers to (config.hosts, DNS rebinding and Host
# header protection), read from the ENV:
#
#   APP_HOST         the public host, also used in mail links (default
#                    credentials.app_host, then "cinquante.app")
#   APP_EXTRA_HOSTS  more hosts, comma-separated (a www. alias, a second domain)
#
# The /up health check is answered whatever the Host header: Kamal's proxy
# calls it by IP.
module AppHosts
  DEFAULT = "cinquante.app".freeze
  HEALTH_CHECK = ->(request) { request.path == "/up" }

  def self.primary(env = ENV, credentials = nil)
    env["APP_HOST"].presence || credentials&.dig(:app_host).presence || DEFAULT
  end

  def self.all(env = ENV, credentials = nil)
    extra = env["APP_EXTRA_HOSTS"].to_s.split(",").map(&:strip).reject(&:empty?)
    [ primary(env, credentials), *extra ].map(&:downcase).uniq
  end
end
