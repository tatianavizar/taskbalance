# Back-office CSS (ActiveAdmin 4) with the standalone Tailwind CLI that
# tailwindcss-rails ships: no Node, no npm package, no node_modules.
#
# ActiveAdmin's own setup asks for `@activeadmin/activeadmin` from npm and
# a Node `tailwindcss`. The standalone binary has no node_modules to resolve
# `tailwindcss/plugin`, `tailwindcss/defaultTheme` and `tailwindcss/colors`
# from, so the gem's plugin.js is rewritten at build time (see
# `ActiveAdminAssets.loadable_plugin`) and the entry point is generated with the
# gem's real path. Both land in tmp/active_admin/; nothing generated is committed,
# so an ActiveAdmin upgrade is picked up by the next build.
#
#   bin/rails active_admin:css       # builds app/assets/builds/active_admin.css
#   bin/rails tailwindcss:build      # app CSS, then this one (also assets:precompile)
module ActiveAdminAssets
  OUT_DIR = "tmp/active_admin".freeze

  # Values the gem's plugin reads from Tailwind's default theme (it only uses these).
  PRELUDE = <<~JS.freeze
    const plugin = (callback) => callback;
    const spacing = { 2: '0.5rem', 3: '0.75rem', 8: '2rem' };
    const borderWidth = { DEFAULT: '1px' };
    const borderRadius = { DEFAULT: '0.25rem' };
    const colors = {
      blue: { 600: '#2563eb' },
      gray: { 100: '#f3f4f6', 200: '#e5e7eb', 500: '#6b7280' }
    };
  JS

  module_function

  def gem_path
    Gem.loaded_specs.fetch("activeadmin").full_gem_path
  end

  # plugin.js minus its three `tailwindcss/*` imports, which the prelude replaces.
  def loadable_plugin
    source = File.read(File.join(gem_path, "plugin.js"))
    body = source.lines.reject { |line| line.match?(%r{\Aimport .* from 'tailwindcss/}) || line.start_with?("const { spacing") }
    unless body.size == source.lines.size - 4
      raise "ActiveAdmin's plugin.js changed: update ActiveAdminAssets (lib/tasks/active_admin_assets.rake)"
    end

    PRELUDE + body.join
  end

  def entry_point(root)
    gem = gem_path
    <<~CSS
      @import "tailwindcss";
      @import "#{root.join("app/assets/tailwind/tokens.css")}";
      @plugin "./plugin.js";
      @source "#{gem}/vendor/javascript/flowbite.js";
      @source "#{gem}/plugin.js";
      @source "#{gem}/app/views";
      @source "#{root.join("app/admin")}";
      @source "#{root.join("app/views/active_admin")}";
      @source "#{root.join("app/views/admin")}";
      @source "#{root.join("app/views/layouts")}";
      @import "#{root.join("app/assets/tailwind/active_admin.css")}";
    CSS
  end

  def prepare(root)
    dir = root.join(OUT_DIR)
    FileUtils.mkdir_p(dir)
    File.write(dir.join("plugin.js"), loadable_plugin)
    File.write(dir.join("input.css"), entry_point(root))
    dir.join("input.css")
  end

  def command(root, debug: false)
    input = prepare(root)
    command = [ Tailwindcss::Ruby.executable, "-i", input.to_s, "-o", root.join("app/assets/builds/active_admin.css").to_s ]
    command << "--minify" unless debug || Rails.application.config.assets.css_compressor.present?
    command
  end
end

namespace :active_admin do
  desc "Build the back-office CSS (app/assets/builds/active_admin.css)"
  task css: :environment do |_, args|
    command = ActiveAdminAssets.command(Rails.root, debug: args.extras.include?("debug"))
    system(*command, exception: true)
  end
end

# The back office is part of every app build.
Rake::Task["tailwindcss:build"].enhance { Rake::Task["active_admin:css"].invoke }
