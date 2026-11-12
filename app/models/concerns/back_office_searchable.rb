# Ransack 4 refuses to search an attribute unless the model allows it. The
# back office (ActiveAdmin filters) only searches what each model lists here,
# and no association: a filter can never reach a log or a preference.
#
#   self.ransackable_attribute_names = %w[email created_at]
module BackOfficeSearchable
  extend ActiveSupport::Concern

  included do
    class_attribute :ransackable_attribute_names, default: []
  end

  class_methods do
    def ransackable_attributes(_auth_object = nil)
      ransackable_attribute_names
    end

    def ransackable_associations(_auth_object = nil)
      []
    end
  end
end
