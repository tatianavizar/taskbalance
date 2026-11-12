# ActiveAdmin builds its ORDER BY from `params[:order]` ("users.email_desc",
# "household_members.empty_weeks_streak_asc") without asking Ransack, so a
# sort could rank rows by any column of any table: per-member figures,
# password hashes, tokens (an oracle), and an unknown table is a 500. This
# concern, included in every ActiveAdmin controller, lets through only the
# columns a resource lists with `sortable_by`; anything else, and anything with
# a dot, is dropped and the default order applies. Same for Ransack's
# `q[s]`. A resource that lists nothing cannot be sorted at all.
#
#   controller do
#     sortable_by :name, :created_at
#   end
module BackOfficeSortable
  extend ActiveSupport::Concern

  ORDER_PARAM = /\A(\w+)_(asc|desc)\z/
  RANSACK_SORT = /\A(\w+)( (asc|desc))?\z/i

  included do
    class_attribute :sortable_column_names, default: [].freeze
    before_action :restrict_sort_params
  end

  class_methods do
    def sortable_by(*names)
      self.sortable_column_names = names.flatten.map(&:to_s).freeze
    end
  end

  private

  def restrict_sort_params
    params.delete(:order) unless sort_allowed?(params[:order], ORDER_PARAM)

    q = params[:q]
    return unless q.respond_to?(:key?) && q.key?(:s)

    sorts = Array(q[:s])
    q.delete(:s) unless sorts.all? { |sort| sort_allowed?(sort, RANSACK_SORT) }
  end

  def sort_allowed?(value, pattern)
    return true if value.blank?
    return false unless value.is_a?(String)

    match = pattern.match(value)
    match.present? && sortable_column_names.include?(match[1])
  end
end
