# Limit of open conversations an agent can hold in an inbox before
# auto-assignment skips them (`auto_assignment_config['max_assignment_limit']`).
#
# Multiplas fork: upstream only enforces this setting in the Enterprise
# edition. This is an independent implementation for the CE build, used by both
# the legacy (V1) round robin and AutoAssignment::AssignmentService (V2).
# Conversations above the limit stay unassigned until an agent frees a slot.
module InboxAssignmentLimit
  extend ActiveSupport::Concern

  included do
    validate :validate_max_assignment_limit
  end

  def max_assignment_limit
    value = (auto_assignment_config || {})['max_assignment_limit']
    return if value.blank?

    value.to_i
  end

  # User ids that already hold `max_assignment_limit` open conversations here.
  def user_ids_at_assignment_limit
    limit = max_assignment_limit
    return [] unless limit&.positive?

    conversations.open
                 .where.not(assignee_id: nil)
                 .group(:assignee_id)
                 .having('COUNT(*) >= ?', limit)
                 .pluck(:assignee_id)
  end

  private

  def validate_max_assignment_limit
    value = (auto_assignment_config || {})['max_assignment_limit']
    return if value.blank?
    return if value.to_s.match?(/\A\d+\z/) && value.to_i.positive?

    errors.add(:auto_assignment_config, 'max_assignment_limit must be a positive integer')
  end
end
