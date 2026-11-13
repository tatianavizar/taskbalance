# ActiveAdmin 4.0.0.beta23 and code reloading in development.
#
# ActiveAdmin's base controllers (ActiveAdmin::ResourceController, PageController)
# live in the engine's app/ and are reloaded by Zeitwerk, but the controllers it
# generates for each resource (Admin::AdminActionsController, ...) are created
# with `eval` and are not. When a reload leaves one behind (a load that failed
# halfway never registers it, so `unload!` never removes it), the next
# `class Admin::X < ActiveAdmin::ResourceController` hits a stale class and
# raises "superclass mismatch". That exception happens while the routes are
# being drawn, so the server answers "No route matches" for every URL until it
# is restarted.
#
# Fix: before generating a controller, drop a stale one whose superclass is not
# the current base class. A controller registered twice in the same load keeps
# its class (same superclass), as ActiveAdmin expects.
module ActiveAdminStaleControllerFix
  def register_resource_controller(config)
    drop_stale_controller(config.controller_name, ActiveAdmin::ResourceController)
    super
  end

  def register_page_controller(config)
    drop_stale_controller(config.controller_name, ActiveAdmin::PageController)
    super
  end

  private

  def drop_stale_controller(controller_name, base)
    *parents, name = controller_name.split("::")
    parent = parents.empty? ? Object : parents.join("::").safe_constantize
    return unless parent&.const_defined?(name, false)

    parent.send(:remove_const, name) unless parent.const_get(name, false).superclass == base
  end
end

ActiveAdmin::Namespace.prepend(ActiveAdminStaleControllerFix)
