# frozen_string_literal: true

class Complaint < ApplicationRecord
  include AASM

  NEEDS_ACTION_STATES = %w[submitted].freeze

  validates :first_name, :last_name, :email, :phone, :complaint, :task_number, presence: true

  scope :needs_action, -> { where(state: NEEDS_ACTION_STATES) }

  aasm column: 'state', whiny_transitions: true do
    state :submitted, initial: true
    state :closed

    event :resolve do
      transitions from: :submitted, to: :closed
    end
  end

  def creator_name
    [first_name, last_name].join(' ')
  end

  def resolvable?
    # TODO: when complaint can be resolved?
    submitted?
  end
end
