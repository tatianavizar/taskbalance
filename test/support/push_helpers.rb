# FCM without the network: fake service account credentials and a transport
# that records requests and answers from a script.
module PushHelpers
  # One RSA key for the whole run (generating one is slow).
  def self.rsa_key
    @rsa_key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def fcm_credentials
    Push::Fcm::Credentials.new(project_id: "cinquante-test", client_email: "push@cinquante-test.iam.gserviceaccount.com",
                               private_key: PushHelpers.rsa_key.to_pem, token_uri: Push::Fcm::DEFAULT_TOKEN_URI)
  end

  class FakeTransport
    Request = Data.define(:url, :headers, :body)

    attr_reader :requests

    # `send_responses`: [status, body] answered to successive message sends
    # (the last one repeats). The token endpoint always answers a token.
    def initialize(send_responses = [ [ 200, '{"name":"projects/cinquante-test/messages/1"}' ] ])
      @send_responses = send_responses.dup
      @requests = []
    end

    def call(url, headers:, body:)
      @requests << Request.new(url, headers, body)
      return [ 200, JSON.generate(access_token: "access-#{token_requests.size}", expires_in: 3599) ] if url == Push::Fcm::DEFAULT_TOKEN_URI

      @send_responses.size > 1 ? @send_responses.shift : @send_responses.first
    end

    def token_requests = @requests.select { |r| r.url == Push::Fcm::DEFAULT_TOKEN_URI }
    def sends = @requests.reject { |r| r.url == Push::Fcm::DEFAULT_TOKEN_URI }
    def sent_messages = sends.map { |r| JSON.parse(r.body)["message"] }
  end

  # FCM configured with `transport` for the block.
  def with_fcm(transport = FakeTransport.new)
    Push::Fcm.credentials = fcm_credentials
    Push::Fcm.transport = transport
    Push::Fcm.reset!
    yield transport
  ensure
    Push::Fcm.credentials = nil
    Push::Fcm.transport = nil
    Push::Fcm.reset!
  end

  def fcm_error(status, code, error_code: nil, message: "error")
    details = error_code ? [ { "@type" => "type.googleapis.com/google.firebase.fcm.v1.FcmError", "errorCode" => error_code } ] : []
    [ status, JSON.generate(error: { code: status, message: message, status: code, details: details }) ]
  end
end
