# Secret tokens that live in the URL path, not in a query parameter, so
# filter_parameters does not reach them in the "Started GET …" line. Whoever
# reads the logs must not be able to open an invitation or switch someone's
# notifications off:
#
#   /invitations/<token>[/claim|accept|decline|waiting]
#   /desinscription/<token>[/reactiver]
#
# The parameters themselves are already filtered (:token in
# filter_parameter_logging.rb); a redirect to such a path logs
# "Redirected to [FILTERED]".
module RequestLogFilter
  FILTERED = "[FILTERED]".freeze
  # The token is the segment right after these prefixes (at the start of a
  # path, or after the host of a redirect URL).
  TOKEN_PATH = %r{\A((?:[a-z]+://[^/]+)?/(?:invitations|desinscription)/)[^/?#]+}

  def self.filter_path(path)
    path.to_s.sub(TOKEN_PATH, "\\1#{FILTERED}")
  end

  # Rails::Rack::Logger writes the "Started …" line from here.
  module StartedRequestMessage
    private

    def started_request_message(request)
      super.sub(request.filtered_path) { RequestLogFilter.filter_path(request.filtered_path) }
    end
  end
end

Rails::Rack::Logger.prepend(RequestLogFilter::StartedRequestMessage)
Rails.application.config.filter_redirect << RequestLogFilter::TOKEN_PATH
