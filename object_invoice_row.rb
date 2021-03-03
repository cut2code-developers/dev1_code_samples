# frozen_string_literal: true

class Billing
  class ObjectInvoiceRow < ApplicationRecord
    belongs_to :object_invoice, class_name: 'Billing::ObjectInvoice'

    AVAILABLE_UNITS = %w[m2 m3 kwh piece times litres].freeze
    AVAILABLE_VAT_TYPES = %w[0 9 20 n/a].freeze
    VAT_MAPPING = {
      '0' => 0,
      '9' => 0.09,
      '20' => 0.2,
      'n/a' => 0
    }.freeze

    validates :unit, inclusion: { in: AVAILABLE_UNITS }
    validates :cost_type, :amount, :unit_price, presence: true

    def total
      (amount || 1) * (unit_price || 0)
    end

    def total_with_vat
      total + vat_amount
    end

    def vat_amount
      total * (VAT_MAPPING[vat] || 0)
    end

    def to_liquid
      {
        cost_type: cost_type,
        description: description,
        amount: amount,
        unit: I18n.t(unit, scope: :available_units),
        unit_price: unit_price,
        vat: I18n.t(vat, scope: :available_vat_type),
        vat_amount: vat_amount,
        total_with_vat: total_with_vat
      }
    end
  end
end
