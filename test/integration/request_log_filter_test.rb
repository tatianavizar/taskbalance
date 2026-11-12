require "test_helper"

# Invitation and unsubscribe tokens never reach the logs in clear.
class RequestLogFilterTest < ActionDispatch::IntegrationTest
  def logged
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end

  test "the path of an invitation is filtered in the Started line" do
    token = "secret-invitation-token-123"
    log = logged { get invitation_path(token) }

    assert_includes log, %(Started GET "/invitations/[FILTERED]")
    assert_not_includes log, token
  end

  test "the path of an unsubscribe link is filtered, its sub-actions too" do
    token = Notifications::Unsubscribe.token_for(users(:alice), "alert")
    log = logged do
      get unsubscribe_path(token)
      post resubscribe_path(token)
    end

    assert_includes log, %(Started GET "/desinscription/[FILTERED]")
    assert_includes log, %(Started POST "/desinscription/[FILTERED]/reactiver")
    assert_not_includes log, token
  end

  test "a redirect to an invitation does not log the token" do
    token = "another-secret-token"
    log = logged { get new_user_registration_path(invitation_token: token) }

    assert_response :redirect
    assert_not_includes log, token
  end

  test "other paths are logged as they are" do
    assert_equal "/households/12/invitations/3", RequestLogFilter.filter_path("/households/12/invitations/3")
    assert_equal "/invitations/[FILTERED]/accept?x=1", RequestLogFilter.filter_path("/invitations/abc/accept?x=1")
    log = logged { get new_user_session_path }
    assert_includes log, %(Started GET "/users/sign_in")
  end
end
