# frozen_string_literal: true

class BiddingManager
  include ActiveModel::Model

  attr_accessor :bidding, :user_id, :expected_delivery_date

  validates :bidding, :user_id, presence: true

  def activate
    if user_id.blank?
      bidding.errors.add(:workerer_id, :blank)
      return false
    end

    if expected_delivery_date.blank?
      bidding.errors.add(:expected_delivery_date, :blank)
      return false
    end
    bidding.update!(
      workerer_id: user_id,
      expected_delivery_date: expected_delivery_date,
      status: Bidding::STATUSES[:activated]
    )
  end

  def finish
    ActiveRecord::Base.transaction do
      bidding.bidding_rows.each do |row|
        row.update!(order_status: BiddingRow::ORDER_STATUSES[:arrived])
      end
      bidding.update!(status: Bidding::STATUSES[:finished])
    end
  end

  def archive
    bidding.status = Bidding::STATUSES[:timed_out] if bidding.forwarded? || bidding.pending?
    bidding.archived_at = Time.zone.now
    bidding.archived_by = user_id
    bidding.save!
  end
end
