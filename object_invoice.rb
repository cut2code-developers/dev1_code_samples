# frozen_string_literal: true

class Billing
  class ObjectInvoice < ApplicationRecord
    include AASM
    include Storext.model

    store_attributes :custom_data do
      recipient_name String
      recipient_address String
      recipient_personal_code String
      recipient_register_code String
      recipient_email String
      recipient_phone String
      total_amount Float, default: 0
      total_amount_with_vat Float, default: 0
      vat_amount Float, default: 0
    end

    belongs_to :contract, optional: true
    belongs_to :property, optional: true
    belongs_to :workspace

    has_many :rows, class_name: 'Billing::ObjectInvoiceRow', dependent: :restrict_with_error
    has_many :payments, class_name: 'Billing::ObjectInvoicePayment', dependent: :restrict_with_error

    accepts_nested_attributes_for :rows, allow_destroy: true, reject_if: ->(c) { c[:cost_type].blank? }

    scope :unsent, -> { where(sent_at: nil, state: STATE_UNSENT) }
    scope :sent, -> { where.not(sent_at: nil).where(state: STATE_SENT) }
    scope :paid, -> { where.not(sent_at: nil).where(state: STATE_PAID) }

    before_validation :set_number
    before_save :calculate_amounts

    validates :number, uniqueness: { scope: :workspace_id }
    validates :number, :invoice_date, :due_date, presence: true
    validates :contract_id, presence: true, if: -> { !custom_recipient }
    validates :recipient_name, :recipient_address, :recipient_email,
              :recipient_phone, presence: true, if: -> { custom_recipient }

    aasm column: 'state', whiny_transitions: false do
      state :unsent, initial: true
      state :sent
      state :partly_paid
      state :paid

      event :send_payment, after_commit: :send_to_payer do
        transitions from: :unsent, to: :sent
      end

      event :pay, after_commit: :pay_invoice! do
        transitions from: :sent, to: :partly_paid, guard: :partly_paid?
        transitions from: :partly_paid, to: :paid, guard: :fully_paid?
        transitions from: :sent, to: :paid, guard: :fully_paid?
      end
    end

    def payable?
      (sent? || partly_paid?) && !fully_paid?
    end

    def payer_name
      if custom_recipient
        recipient_name
      else
        contract&.tenant_data&.full_name
      end
    end

    def payer_address
      if custom_recipient
        recipient_address
      else
        contract&.property&.address
      end
    end

    def payer_email
      if custom_recipient
        recipient_email
      else
        contract&.tenant_data&.email
      end
    end

    def payer_phone
      if custom_recipient
        recipient_phone
      else
        contract&.tenant_data&.phone_number
      end
    end

    def partly_paid?
      payments_amount.positive? && payments_amount < total_amount_with_vat
    end

    def fully_paid?
      payments_amount >= total_amount_with_vat
    end

    def payments_amount
      payments.pluck(:amount).sum
    end

    alias paid_amount payments_amount

    def unpaid?
      !fully_paid?
    end

    def unpaid_amount
      total_amount_with_vat - payments_amount
    end

    def liquid_presenter
      ObjectInvoiceLiquidPresenter.new(self)
    end

    def rows_liquid_keys
      rows.to_a.map(&:to_liquid)
    end

    private

    def send_to_payer
      ObjectInvoiceService.new(self).send_to_payer
    end

    def pay_invoice!; end

    def set_number
      return if number.present?

      workspace.invoice_number_counter = (workspace.invoice_number_counter + 1)
      workspace.save validate: false
      workspace.reload
      datestring = Time.zone.today.strftime('%Y%m%d')
      self.number = "#{workspace.invoice_number_prefix}#{datestring}#{workspace.invoice_number_counter}"
    end

    def calculate_amounts
      self.total_amount = rows&.map(&:total)&.sum
      self.total_amount_with_vat = rows&.map(&:total_with_vat)&.sum
      self.vat_amount = rows&.map(&:vat_amount)&.sum
    end
  end
end
