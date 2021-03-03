# frozen_string_literal: true

class VirtualMeterCalculation < ApplicationRecord
  AVAILABLE_FORMULAS = %w[+ -].freeze

  validates :order, :formula_before, :object_a_id, presence: true
  validates :order, uniqueness: { scope: :virtual_meter_id }
  validates :formula_before, inclusion: { in: AVAILABLE_FORMULAS }
  validates :formula_after, inclusion: { in: AVAILABLE_FORMULAS, allow_blank: true }

  validate :objects_not_same
  validate :object_not_same_as_meter

  belongs_to :virtual_meter
  belongs_to :object_a, class_name: 'VirtualMeter'
  belongs_to :object_b, class_name: 'VirtualMeter', optional: true

  private

  def objects_not_same
    return if object_b_id.blank?

    message = I18n.t('cannot_be_same_as_object_a', scope: %i[dashkit_virtual_meter])
    errors.add(:object_b_id, message) if object_a_id == object_b_id
  end

  def object_not_same_as_meter
    message = I18n.t('cannot_use_self_in_calculation', scope: %i[dashkit_virtual_meter])
    errors.add(:object_a_id, message) if object_a_id == virtual_meter.id
    errors.add(:object_b_id, message) if object_b_id == virtual_meter.id
  end
end
