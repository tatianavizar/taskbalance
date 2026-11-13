require "test_helper"

class PushFcmTest < ActiveSupport::TestCase
  include PushHelpers

  teardown { Push::Fcm.reset! }

  def client(transport, clock: -> { Time.utc(2026, 11, 13, 9) })
    Push::Fcm.new(fcm_credentials, transport: transport, clock: clock)
  end

  def deliver(client)
    client.deliver(token: "device-token", notification: { title: "Titre", body: "Ligne" }, data: { "path" => "/notifications/1", "id" => 1 })
  end

  # ---- configuration --------------------------------------------------------

  test "not configured without credentials" do
    assert_nil Push::Fcm.credentials_from({}, nil)
    assert_not Push::Fcm.configured?
  end

  test "reads the service account JSON from the ENV, the project id overridable" do
    json = JSON.generate(project_id: "p1", client_email: "a@b.iam", private_key: "KEY", token_uri: "https://example.test/token")

    credentials = Push::Fcm.credentials_from({ "FCM_CREDENTIALS_JSON" => json }, nil)
    assert_equal "p1", credentials.project_id
    assert_equal "a@b.iam", credentials.client_email
    assert_equal "https://example.test/token", credentials.token_uri

    assert_equal "p2", Push::Fcm.credentials_from({ "FCM_CREDENTIALS_JSON" => json, "FCM_PROJECT_ID" => "p2" }, nil).project_id
  end

  test "reads the encrypted credentials, with Google's token endpoint by default" do
    credentials = Push::Fcm.credentials_from({}, { project_id: "p1", client_email: "a@b.iam", private_key: "KEY" })

    assert_equal Push::Fcm::DEFAULT_TOKEN_URI, credentials.token_uri
  end

  test "incomplete or unreadable credentials turn push off instead of raising" do
    assert_nil Push::Fcm.credentials_from({ "FCM_CREDENTIALS_JSON" => "{not json" }, nil)
    assert_nil Push::Fcm.credentials_from({ "FCM_CREDENTIALS_JSON" => JSON.generate(project_id: "p1") }, nil)
    assert_nil Push::Fcm.credentials_from({ "FCM_CREDENTIALS_PATH" => "/nonexistent/fcm.json" }, nil)
  end

  # ---- OAuth ----------------------------------------------------------------

  test "the JWT assertion is signed RS256 by the service account key, for the messaging scope" do
    assertion = client(PushHelpers::FakeTransport.new).jwt_assertion(1_800_000_000)
    header, claims, signature = assertion.split(".")
    decode = ->(part) { Base64.urlsafe_decode64(part + "=" * (-part.size % 4)) }

    assert_equal({ "alg" => "RS256", "typ" => "JWT" }, JSON.parse(decode.(header)))
    claims = JSON.parse(decode.(claims))
    assert_equal "push@cinquante-test.iam.gserviceaccount.com", claims["iss"]
    assert_equal Push::Fcm::SCOPE, claims["scope"]
    assert_equal Push::Fcm::DEFAULT_TOKEN_URI, claims["aud"]
    assert_equal 1_800_000_000 + 3600, claims["exp"]
    assert PushHelpers.rsa_key.public_key.verify(OpenSSL::Digest::SHA256.new, decode.(signature), "#{header}.#{claims_part(assertion)}")
  end

  def claims_part(assertion) = assertion.split(".")[1]

  test "the access token is fetched once and reused until shortly before it expires" do
    transport = PushHelpers::FakeTransport.new
    now = Time.utc(2026, 11, 13, 9)
    fcm = client(transport, clock: -> { now })

    2.times { assert deliver(fcm).ok? }
    assert_equal 1, transport.token_requests.size
    assert_match "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer", transport.token_requests.first.body
    assert_equal "Bearer access-1", transport.sends.last.headers["Authorization"]

    now += 56.minutes
    deliver(fcm)
    assert_equal 2, transport.token_requests.size
  end

  test "a refused token request is a failure, a busy token endpoint a retry" do
    transport = PushHelpers::FakeTransport.new
    def transport.call(url, headers:, body:) = [ 400, "{}" ]
    assert deliver(client(transport)).failed?

    Push::Fcm.reset!
    busy = PushHelpers::FakeTransport.new
    def busy.call(url, headers:, body:) = [ 503, "" ]
    assert deliver(client(busy)).retry?
  end

  # ---- the message ------------------------------------------------------------

  test "the message targets the token, carries the text and string data, for both platforms" do
    transport = PushHelpers::FakeTransport.new
    assert deliver(client(transport)).ok?

    request = transport.sends.first
    assert_equal "https://fcm.googleapis.com/v1/projects/cinquante-test/messages:send", request.url
    message = transport.sent_messages.first
    assert_equal "device-token", message["token"]
    assert_equal({ "title" => "Titre", "body" => "Ligne" }, message["notification"])
    assert_equal({ "path" => "/notifications/1", "id" => "1" }, message["data"])
    assert_equal "general", message.dig("android", "notification", "channel_id")
    assert_equal "default", message.dig("apns", "payload", "aps", "sound")
  end

  # ---- errors -----------------------------------------------------------------

  test "a dead token is reported as invalid" do
    [
      fcm_error(404, "NOT_FOUND", error_code: "UNREGISTERED"),
      fcm_error(403, "PERMISSION_DENIED", error_code: "SENDER_ID_MISMATCH"),
      fcm_error(400, "INVALID_ARGUMENT", error_code: "INVALID_ARGUMENT", message: "The registration token is not a valid FCM registration token")
    ].each do |response|
      Push::Fcm.reset!
      assert deliver(client(PushHelpers::FakeTransport.new([ response ]))).invalid_token?, response.inspect
    end
  end

  test "a bad payload is a failure, not a dead token" do
    response = fcm_error(400, "INVALID_ARGUMENT", error_code: "INVALID_ARGUMENT", message: "Invalid JSON payload received.")

    assert deliver(client(PushHelpers::FakeTransport.new([ response ]))).failed?
  end

  test "overload, server errors and network errors are retried" do
    [ fcm_error(429, "RESOURCE_EXHAUSTED", error_code: "QUOTA_EXCEEDED"), fcm_error(503, "UNAVAILABLE"), [ 500, "oops" ] ].each do |response|
      Push::Fcm.reset!
      assert deliver(client(PushHelpers::FakeTransport.new([ response ]))).retry?, response.inspect
    end

    broken = PushHelpers::FakeTransport.new
    def broken.call(url, headers:, body:) = raise(Errno::ECONNRESET)
    assert deliver(client(broken)).retry?
  end

  test "an expired access token is dropped and the send retried" do
    transport = PushHelpers::FakeTransport.new([ fcm_error(401, "UNAUTHENTICATED"), [ 200, "{}" ] ])
    fcm = client(transport)

    assert deliver(fcm).retry?
    assert deliver(fcm).ok?
    assert_equal 2, transport.token_requests.size
  end
end
