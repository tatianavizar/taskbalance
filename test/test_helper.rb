ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup { Rails.cache.clear }

    # A chore saved without validations, for a household with nobody to
    # assign it to (a chore needs at least one assignee).
    def insert_chore!(household, **attributes)
      Chore.new(household: household, **attributes).tap { |chore| chore.save!(validate: false) }
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # The page contains `text`, HTML entities decoded (« l'a » is « l&#39;a »).
  def assert_text(text)
    assert_includes CGI.unescapeHTML(response.body), text
  end

  # The message of an inline field error, without its "!" icon.
  def assert_field_error(message)
    assert_select ".field-error span:not([aria-hidden])", message
  end
end
