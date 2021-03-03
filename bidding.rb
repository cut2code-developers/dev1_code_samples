# frozen_string_literal: true

class Bidding < ApplicationRecord
  acts_as_paranoid

  STATUSES = {
    pending: 0,
    forwarded: 25,
    activated: 50,
    finished: 100,
    canceled: 150,
    timed_out: 250
  }.freeze

  enum status: STATUSES

  before_validation :import_info_from_work_package
  after_create :add_bidding_info_from_work_package

  belongs_to :client
  belongs_to :car, optional: true
  belongs_to :work_package, optional: true
  has_many :bidding_rows, dependent: :destroy
  has_many :bidding_jobs, dependent: :destroy
  has_many :payments, dependent: :destroy
  belongs_to :creator, class_name: 'User', foreign_key: :created_by, optional: true
  belongs_to :updater, class_name: 'User', foreign_key: :updated_by, optional: true
  belongs_to :workerer, class_name: 'User', foreign_key: :workerer_id, optional: true
  belongs_to :archiver, class_name: 'User', foreign_key: :archived_by, optional: true

  validates :description, :car_id, presence: true

  def self.translated_statuses
    STATUSES.map do |key, value|
      [translated_status(key), value]
    end
  end

  def self.translated_status(status)
    I18n.t(status) if status
  end

  def active?
    status.to_sym == :activated
  end

  def forwarded?
    status.to_sym == :forwarded
  end

  def pending?
    status.to_sym == :pending
  end

  def archived?
    archived_at.present?
  end

  def total_price_with_expenses
    jobs_price + rows_price_with_expenses
  end

  def parts_price_with_expenses
    rows_price_with_expenses
  end

  def parts_price
    rows_price
  end

  def jobs_price
    bidding_jobs.map(&:fixed_price).sum || 0
  end

  def profit
    total_price_with_expenses - parts_price
  end

  def advance_payment
    rows_price_with_expenses
  end

  def paid_sum
    payments.map(&:sum).sum || 0
  end

  def unpaid_sum
    total_price_with_expenses - paid_sum
  end

  def expected_work_time
    bidding_jobs.map(&:hours).sum || 0
  end

  def to_s
    "#{created_at.strftime('%F %T')} - #{description} - #{total_price_with_expenses} €"
  end

  private

  def rows_price_with_expenses
    bidding_rows.map(&:total_price_with_expenses).sum || 0
  end

  def rows_price
    bidding_rows.map(&:total_price).sum || 0
  end

  def import_info_from_work_package
    return unless work_package

    self.description = work_package.title if description.blank?
  end

  def add_bidding_info_from_work_package
    BiddingRowsManager.new(bidding: self).add_rows
    BiddingRowsManager.new(bidding: self).add_jobs
  end
end
