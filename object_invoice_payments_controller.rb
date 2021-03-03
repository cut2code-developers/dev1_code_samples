# frozen_string_literal: true

module Billing
  class ObjectInvoicePaymentsController < ApplicationController
    layout 'application_dashkit'

    before_action :set_workspace, :set_invoice
    before_action :set_payment, only: %i[edit update show destroy]

    def index
      authorize(@invoice)
      @payments = @invoice.payments
    end

    def show
      authorize(@invoice)
    end

    def new
      @payment = @invoice.payments.new
      authorize(@invoice)
    end

    def create
      @payment = @invoice.payments.new(payment_params)
      authorize(@invoice)
      if @payment.save
        flash[:notice] = t('payment_created', scope: %i[billing object_invoice_payments])
        redirect_to billing_workspace_invoice_payments_path(@workspace, @invoice)
      else
        render :new
      end
    end

    def edit
      authorize(@invoice)
    end

    def update
      authorize(@invoice)
      if @payment.update(payment_params)
        flash[:notice] = t('payment_updated', scope: %i[billing object_invoice_payments])
        redirect_to billing_workspace_invoice_payments_path(@workspace, @invoice)
      else
        render :edit
      end
    end

    def destroy
      authorize(@workspace.object_invoices.new, :create?)
      if @payment.destroy
        flash.notice = t('payment_deleted', scope: %i[billing object_invoice_payments])
      else
        flash[:danger] = t('payment_cannot_be_deleted', scope: %i[billing object_invoice_payments])
      end
      redirect_to billing_workspace_invoice_payments_path(@workspace, @invoice)
    end

    private

    def set_workspace
      @workspace = Workspace.find(params[:workspace_id])
    end

    def set_invoice
      @invoice = @workspace.object_invoices.find(params[:invoice_id])
    end

    def set_payment
      @payment = @invoice.payments.find(params[:id])
    end

    def payment_params
      params.require(:billing_object_invoice_payment).permit(
        :amount, :description, :payment_date
      )
    end
  end
end
