require "net/http"

module Push
  # Firebase Cloud Messaging, HTTP v1 API, for both platforms (FCM relays to
  # APNs for iOS). Standard library only: the OAuth 2 access token comes from a
  # JWT signed with the service account's RSA key (RS256), exchanged at
  # Google's token endpoint, and kept in memory until shortly before it expires.
  #
  #   Push::Fcm.configured?                  # credentials present?
  #   Push::Fcm.client.deliver(token: "...", notification: { title:, body: }, data: { "path" => "/..." })
  #   # => Push::Fcm::Result (:ok, :invalid_token, :retry or :failed)
  #
  # Credentials, first found wins (nothing set: push is off, and the Notifier
  # falls back on email because Channels::Push is never available):
  #   FCM_CREDENTIALS_JSON   the service account JSON itself
  #   FCM_CREDENTIALS_PATH   a path to that JSON file
  #   credentials `fcm:`     project_id, client_email, private_key
  # FCM_PROJECT_ID overrides the project id of any of them.
  #
  # Error mapping (https://firebase.google.com/docs/reference/fcm/rest/v1/ErrorCode):
  #   UNREGISTERED, SENDER_ID_MISMATCH, or INVALID_ARGUMENT about the
  #   registration token                      -> :invalid_token (prune the device)
  #   401 (expired access token)              -> :retry, access token dropped
  #   429, 5xx, UNAVAILABLE, INTERNAL, QUOTA_EXCEEDED, network errors -> :retry
  #   anything else (bad payload, THIRD_PARTY_AUTH_ERROR...) -> :failed
  class Fcm
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging".freeze
    DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token".freeze
    SEND_URL = "https://fcm.googleapis.com/v1/projects/%s/messages:send".freeze
    TOKEN_LIFETIME = 3600
    TOKEN_MARGIN = 300 # renew five minutes before Google's expiry

    # The Android notification channel the shell creates (native/android).
    ANDROID_CHANNEL = "general".freeze

    Credentials = Data.define(:project_id, :client_email, :private_key, :token_uri)

    Result = Data.define(:status, :error) do
      def ok? = status == :ok
      def invalid_token? = status == :invalid_token
      def retry? = status == :retry
      def failed? = status == :failed
    end

    # The transport answers [status code, body]. Tests replace it.
    class NetHttpTransport
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 10

      def call(url, headers:, body:)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        request = Net::HTTP::Post.new(uri, headers)
        request.body = body
        response = http.request(request)
        [ response.code.to_i, response.body.to_s ]
      end
    end

    NETWORK_ERRORS = [
      Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
      SocketError, EOFError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, IOError
    ].freeze

    RETRY_CODES = %w[UNAVAILABLE INTERNAL QUOTA_EXCEEDED].freeze
    PRUNE_CODES = %w[UNREGISTERED SENDER_ID_MISMATCH].freeze

    class << self
      attr_writer :credentials, :transport

      def configured?
        credentials.present?
      end

      def credentials
        @credentials || credentials_from(ENV, Rails.application.credentials.fcm)
      end

      def transport
        @transport ||= NetHttpTransport.new
      end

      def client
        new(credentials, transport: transport)
      end

      # nil when nothing usable is set. Never raises: a broken configuration
      # turns push off (and is reported), it does not stop email.
      def credentials_from(env, stored)
        raw =
          if env["FCM_CREDENTIALS_JSON"].present? then JSON.parse(env["FCM_CREDENTIALS_JSON"])
          elsif env["FCM_CREDENTIALS_PATH"].present? then JSON.parse(File.read(env["FCM_CREDENTIALS_PATH"]))
          elsif stored.present? then stored.to_h.transform_keys(&:to_s)
          end
        return unless raw

        project_id = env["FCM_PROJECT_ID"].presence || raw["project_id"]
        return if [ project_id, raw["client_email"], raw["private_key"] ].any?(&:blank?)

        Credentials.new(project_id: project_id, client_email: raw["client_email"],
                        private_key: raw["private_key"], token_uri: raw["token_uri"].presence || DEFAULT_TOKEN_URI)
      rescue JSON::ParserError, SystemCallError => e
        Rails.error.report(e, handled: true, context: { push: "fcm credentials" })
        nil
      end

      # In-process cache of access tokens, per service account.
      def access_tokens
        @access_tokens ||= {}
      end

      def token_lock
        @token_lock ||= Mutex.new
      end

      def reset!
        @access_tokens = {}
      end
    end

    def initialize(credentials, transport: self.class.transport, clock: -> { Time.now })
      raise ArgumentError, "FCM is not configured" unless credentials

      @credentials = credentials
      @transport = transport
      @clock = clock
    end

    # notification: { title:, body: } shown by the system.
    # data: string => string, read by the shell when the person taps.
    def deliver(token:, notification:, data: {})
      message = build_message(token, notification, data)
      status, body = @transport.call(format(SEND_URL, @credentials.project_id),
                                     headers: { "Authorization" => "Bearer #{access_token}",
                                                "Content-Type" => "application/json; charset=UTF-8" },
                                     body: JSON.generate(message: message))
      interpret(status, body)
    rescue *NETWORK_ERRORS => e
      Result.new(:retry, e.class.name)
    rescue AuthError => e
      Result.new(e.retry ? :retry : :failed, e.message)
    end

    def build_message(token, notification, data)
      {
        token: token,
        notification: { title: notification[:title].to_s, body: notification[:body].to_s },
        data: data.to_h { |key, value| [ key.to_s, value.to_s ] },
        android: { priority: "HIGH", notification: { channel_id: ANDROID_CHANNEL } },
        apns: { headers: { "apns-priority" => "10" }, payload: { aps: { sound: "default" } } }
      }
    end

    # The signed assertion of the OAuth 2 JWT bearer flow (RFC 7523).
    def jwt_assertion(now = @clock.call.to_i)
      header = { alg: "RS256", typ: "JWT" }
      claims = { iss: @credentials.client_email, scope: SCOPE, aud: @credentials.token_uri,
                 iat: now, exp: now + TOKEN_LIFETIME }
      signing_input = [ header, claims ].map { |part| base64url(JSON.generate(part)) }.join(".")
      key = OpenSSL::PKey::RSA.new(@credentials.private_key)
      "#{signing_input}.#{base64url(key.sign(OpenSSL::Digest::SHA256.new, signing_input))}"
    end

    class AuthError < StandardError
      attr_reader :retry

      def initialize(message, retry_later:)
        super(message)
        @retry = retry_later
      end
    end

    private

    def access_token
      self.class.token_lock.synchronize do
        cached = self.class.access_tokens[@credentials.client_email]
        return cached[:token] if cached && cached[:expires_at] > @clock.call

        self.class.access_tokens[@credentials.client_email] = fetch_access_token
        self.class.access_tokens[@credentials.client_email][:token]
      end
    end

    def fetch_access_token
      status, body = @transport.call(@credentials.token_uri,
                                     headers: { "Content-Type" => "application/x-www-form-urlencoded" },
                                     body: URI.encode_www_form(grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                                               assertion: jwt_assertion))
      unless status == 200
        raise AuthError.new("token endpoint answered #{status}", retry_later: status == 429 || status >= 500)
      end

      json = JSON.parse(body)
      lifetime = json["expires_in"].to_i.positive? ? json["expires_in"].to_i : TOKEN_LIFETIME
      { token: json.fetch("access_token"), expires_at: @clock.call + (lifetime - TOKEN_MARGIN) }
    rescue JSON::ParserError, KeyError
      raise AuthError.new("token endpoint answered an unreadable body", retry_later: true)
    end

    def interpret(status, body)
      return Result.new(:ok, nil) if status == 200

      error = parse_error(body)
      code = fcm_error_code(error) || error["status"]
      message = [ status, code, error["message"] ].compact.join(" ")

      if status == 401
        self.class.access_tokens.delete(@credentials.client_email)
        Result.new(:retry, message)
      elsif PRUNE_CODES.include?(code) || (code == "INVALID_ARGUMENT" && error["message"].to_s.match?(/registration token/i))
        Result.new(:invalid_token, message)
      elsif status == 429 || status >= 500 || RETRY_CODES.include?(code)
        Result.new(:retry, message)
      else
        Result.new(:failed, message)
      end
    end

    def parse_error(body)
      parsed = JSON.parse(body.to_s)
      parsed.is_a?(Hash) && parsed["error"].is_a?(Hash) ? parsed["error"] : {}
    rescue JSON::ParserError
      {}
    end

    def fcm_error_code(error)
      Array(error["details"]).find { |detail| detail.is_a?(Hash) && detail["errorCode"] }&.dig("errorCode")
    end

    def base64url(bytes)
      [ bytes ].pack("m0").tr("+/", "-_").delete("=")
    end
  end
end
