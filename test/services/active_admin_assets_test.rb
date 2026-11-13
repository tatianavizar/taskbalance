require "test_helper"
require "rake"

# The back-office CSS build (lib/tasks/active_admin_assets.rake): the gem's
# plugin.js made loadable by the standalone Tailwind CLI, and the entry point
# that shares the app's tokens.
class ActiveAdminAssetsTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("active_admin:css")
  end

  test "the gem's plugin loses its tailwindcss imports and keeps its body" do
    plugin = ActiveAdminAssets.loadable_plugin
    assert_no_match(%r{from 'tailwindcss/}, plugin)
    assert_includes plugin, "export default plugin("
    assert_includes plugin, ".formtastic"
  end

  test "the entry point imports the shared tokens, not a copy of the palette" do
    entry = ActiveAdminAssets.entry_point(Rails.root)
    assert_includes entry, %(@import "#{Rails.root.join("app/assets/tailwind/tokens.css")}")
    assert_includes entry, "app/views\";"
    assert_no_match(/#[0-9a-f]{6}/i, File.read(Rails.root.join("app/assets/tailwind/active_admin.css")).gsub(/\/\*.*?\*\//m, "").gsub(/#fff\b/, ""),
                    "the admin stylesheet maps onto tokens.css, it does not redefine colours")
  end

  test "the app stylesheet takes its tokens from the same file" do
    assert_includes File.read(Rails.root.join("app/assets/tailwind/application.css")), '@import "./tokens.css"'
    assert_includes File.read(Rails.root.join("app/assets/tailwind/tokens.css")), "@theme static"
  end
end
