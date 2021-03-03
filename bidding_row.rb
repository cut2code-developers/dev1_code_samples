# frozen_string_literal: true

class BiddingRow < ApplicationRecord
  acts_as_paranoid

  ORDER_STATUSES = {
    not_ordered: 0,
    ordered: 50,
    arrived: 100,
    in_stock: 150,
    canceled: 250
  }.freeze

  enum order_status: ORDER_STATUSES

  belongs_to :bidding
  belongs_to :creator, class_name: 'User', foreign_key: :created_by, optional: true
  belongs_to :updater, class_name: 'User', foreign_key: :updated_by, optional: true

  validates :part, :base_price, :count, presence: true
  validates :base_price, :price_with_expenses, :count, numericality: true

  def total_price
    base_price * count
  end

  def total_price_with_expenses
    price_with_expenses * count
  end

  def self.translated_order_statuses
    ORDER_STATUSES.map do |key, value|
      [translated_order_status(key), value]
    end
  end

  def self.translated_order_status(status)
    I18n.t(status) if status
  end

  def count_with_unit
    "#{count} #{unit.present? ? I18n.t(unit) : ''}"
  end
end
