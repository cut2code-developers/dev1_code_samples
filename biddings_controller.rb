# frozen_string_literal: true

class BiddingsController < ApplicationController
  before_action :set_client, only: %i[new create edit update show add_row activate finish cancel forwarded archive]
  before_action :set_bidding, only: %i[show edit update destroy activate finish cancel forwarded archive]

  def index
    @biddings = Bidding.where(archived_at: nil).order(created_at: :desc)
  end

  def archived
    @biddings = Bidding.where('archived_at is not null').order(created_at: :desc)
  end

  def new
    @bidding = @client.biddings.new
  end

  def create
    @bidding = @client.biddings.new(bidding_params)
    if @bidding.save
      redirect_to client_bidding_path(@client, @bidding)
    else
      render :new
    end
  end

  def show
    @bidding_rows = @bidding.bidding_rows.order(:id)
    @bidding_jobs = @bidding.bidding_jobs.order(:id)
    @car = @bidding.car
  end

  def edit; end

  def update
    if @bidding.update(update_params)
      flash[:info] = t('edit_successful')
      redirect_to client_bidding_path(@client, @bidding)
    else
      render :edit
    end
  end

  def destroy; end

  def forwarded
    if @bidding.update(status: Bidding::STATUSES[:forwarded])
      flash[:info] = t('forwarded')
    else
      flash[:error] = t('forwarding_failed')
    end
    redirect_to client_bidding_path(@client, @bidding)
  end

  def activate
    if BiddingManager.new(activation_params).activate
      flash[:info] = t('activated')
      redirect_to client_bidding_path(@client, @bidding)
    else
      render partial: 'activation_modal', status: :unprocessable_entity
    end
  end

  def finish
    if BiddingManager.new(bidding: @bidding).finish
      flash[:info] = t('finished')
    else
      flash[:error] = t('finishing_failed')
    end
    redirect_to client_bidding_path(@client, @bidding)
  end

  def cancel
    if @bidding.update(status: Bidding::STATUSES[:canceled])
      flash[:info] = t('canceled')
    else
      flash[:error] = t('canceling_failed')
    end
    redirect_to client_bidding_path(@client, @bidding)
  end

  def archive
    if BiddingManager.new(bidding: @bidding, user_id: current_user.id).archive
      flash[:info] = t('archived')
    else
      flash[:error] = t('archiving_failed')
    end
    redirect_to client_bidding_path(@client, @bidding)
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def set_bidding
    @bidding = Bidding.find(params[:id])
  end

  def bidding_params
    params.require(:bidding).permit(
      :name, :description,
      :work_package_id, :car_id,
      :create_bidding_rows, :comments
    )
  end

  def update_params
    return bidding_params.merge(activation_params_raw) if @bidding&.persisted? && @bidding&.active?

    bidding_params
  end

  def activation_params_raw
    params.require(:bidding).permit(
      :workerer_id, :expected_delivery_date
    )
  end

  def activation_params
    {
      bidding: @bidding,
      user_id: activation_params_raw[:workerer_id],
      expected_delivery_date: Date.civil(
        activation_params_raw['expected_delivery_date(1i)'].to_i,
        activation_params_raw['expected_delivery_date(2i)'].to_i,
        activation_params_raw['expected_delivery_date(3i)'].to_i
      )
    }
  end
end
