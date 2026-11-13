require "test_helper"
require Rails.root.join("config/app_hosts").to_s

# Production settings that cannot be exercised by booting the test env: the
# shared cache (rate-limit counters), the allowed hosts, the job cleanup.
class ProductionConfigTest < ActiveSupport::TestCase
  PRODUCTION = Rails.root.join("config/environments/production.rb").read

  test "production keeps its cache, rate-limit counters included, in Solid Cache" do
    assert_match(/^\s*config\.cache_store = :solid_cache_store$/, PRODUCTION)

    cache = YAML.load(ERB.new(Rails.root.join("config/cache.yml").read).result, aliases: true)
    assert_equal "cache", cache.dig("production", "database")
    assert_includes Rails.root.join("db/cache_schema.rb").read, %(create_table "solid_cache_entries")
    databases = YAML.load(ERB.new(Rails.root.join("config/database.yml").read).result, aliases: true)
    assert_equal "db/cache_migrate", databases.dig("production", "cache", "migrations_paths")
  end

  test "allowed hosts come from APP_HOST and APP_EXTRA_HOSTS" do
    assert_match(/^\s*config\.hosts = AppHosts\.all\(ENV, Rails\.application\.credentials\)$/, PRODUCTION)
    assert_match(/^\s*config\.host_authorization = \{ exclude: AppHosts::HEALTH_CHECK \}$/, PRODUCTION)

    assert_equal [ "cinquante.app" ], AppHosts.all({})
    assert_equal [ "app.example.org" ], AppHosts.all({}, { app_host: "app.example.org" })
    assert_equal [ "app.cinquante.fr", "www.cinquante.fr", "cinquante.fr" ],
                 AppHosts.all({ "APP_HOST" => "app.cinquante.fr", "APP_EXTRA_HOSTS" => " www.cinquante.fr, ,cinquante.fr,APP.cinquante.fr" })
  end

  test "an unknown Host is refused, except on the /up health check" do
    app = ->(_env) { [ 200, {}, [ "ok" ] ] }
    middleware = ActionDispatch::HostAuthorization.new(app, AppHosts.all({ "APP_HOST" => "cinquante.app" }),
                                                       exclude: AppHosts::HEALTH_CHECK)

    status = ->(host, path) { middleware.call(Rack::MockRequest.env_for("https://#{host}#{path}", "HTTP_HOST" => host)).first }
    assert_equal 200, status.("cinquante.app", "/")
    assert_equal 403, status.("evil.example", "/")
    assert_equal 200, status.("10.0.0.5", "/up")
  end

  test "Solid Queue clears its finished jobs every hour" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    task = recurring.dig("production", "clear_solid_queue_finished_jobs")

    assert_match(/\ASolidQueue::Job\.clear_finished_in_batches\(/, task["command"])
    assert_match(/\Aevery hour/, task["schedule"])
    assert_respond_to SolidQueue::Job, :clear_finished_in_batches
  end
end
