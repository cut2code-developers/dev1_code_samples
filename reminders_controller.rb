# frozen_string_literal: true

class RemindersController < ApplicationController
  layout 'application_dashkit'
  before_action :set_reminder, only: %i[edit update destroy]
  before_action :set_property, only: %i[new create edit update destroy]
  before_action :set_elements, only: %i[new edit update]

  def index
    @reminder_events = ReminderEvent.where(user: current_user)
                         .where(ReminderEvent.arel_table[:remind_at].gteq(Time.zone.now.beginning_of_day))
                         .order(:remind_at)
  end

  def new
    @reminder = @property.reminders.new(event_date: Date.tomorrow, recurrence: Reminder::SINGLE_RECURRENCE_TYPES.first)
    authorize(@reminder)
  end

  def create
    @reminder = @property.reminders.new(reminder_params)
    authorize(@reminder)
    if @reminder.save
      flash[:notice] = t('reminder_added', scope: %i[reminders])
      redirect_to property_path(@property)
    else
      render :new
    end
  end

  def edit; end

  def update
    if @reminder.update(reminder_params)
      flash[:notice] = t('reminder_updated', scope: %i[reminders])
      redirect_to @reminder.edit_redirect_url
    else
      render :edit
    end
  end

  def destroy
    redirect_url = @reminder.edit_redirect_url
    @reminder.destroy
    redirect_to redirect_url
  end

  private

  def set_reminder
    @reminder = Reminder.find(params[:id])
  end

  def set_property
    if @reminder
      @property = @reminder.property
    else
      @property = Property.find(params[:property_id])
    end
  end

  def set_elements
    @elements = @property.elements
  end

  def reminder_params
    params.require(:reminder).permit(
      :body, :event_date, :recurrence, :infinit_recurrence, :recurrence_to,
      reminder_users_attributes: %i[user_id id service_user_id property_task_assignment_id _destroy element_id]
    )
  end
end
