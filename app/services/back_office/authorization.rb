# Who may do what in /admin (ActiveAdmin's authorization adapter, set in
# config/initializers/active_admin.rb). Decision of 2026-11-13:
#
#   superadmin  everything.
#   admin       everything but the team pages (AdminUser) and the individual
#               data of a person (SUPERADMIN_ACTIONS); a deactivated account
#               never gets this far (Devise refuses it).
#
# ActiveAdmin asks with the permission of the action (`:read`, `:create`... or
# the name of a member action) and the resource or its class. Refusals go to
# `on_unauthorized_access` (a redirect with a message). The services check the
# role again (BackOffice::Team, BackOffice::IndividualData).
module BackOffice
  class Authorization < ActiveAdmin::AuthorizationAdapter
    SUPERADMIN_ACTIONS = %i[individual_data].freeze
    SUPERADMIN_RESOURCES = [ AdminUser ].freeze

    def authorized?(action, subject = nil)
      return false unless user.is_a?(AdminUser)
      return true if user.superadmin?

      !(SUPERADMIN_ACTIONS.include?(action&.to_sym) || SUPERADMIN_RESOURCES.include?(subject_class(subject)))
    end

    private

    def subject_class(subject)
      case subject
      when Class then subject
      when ActiveAdmin::Resource then subject.resource_class
      when nil, ActiveAdmin::Page then nil
      else subject.class
      end
    end
  end
end
