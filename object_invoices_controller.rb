# frozen_string_literal: true

module Billing
  class ObjectInvoicesController < ApplicationController
    layout 'application_dashkit'

    before_action :set_workspace, except: %i[all]
    before_action :set_invoice, only: %i[edit update show destroy send_to_payer mark_as_paid download resend_invoice]

    def all
      authorize(current_user, :can_create_object_invoice_somewhere?)
    end

    def index
      authorize(@workspace.object_invoices.new, :create?)
      @unsent_invoices = @workspace.object_invoices.unsent
      @sent_invoices = @workspace.object_invoices.sent
      @paid_invoices = @workspace.object_invoices.paid
    end

    def show
      authorize(@invoice)
    end

    def new
      @invoice = @workspace.object_invoices.new
      authorize(@invoice)
    end

    def create
      @invoice = @workspace.object_invoices.new(invoice_params)
      authorize(@invoice)
      if @invoice.save
        flash[:notice] = t('invoice_created', scope: %i[billing object_invoices])
        redirect_to billing_workspace_invoices_path(@workspace)
      else
        render :new
      end
    end

    def edit
      authorize(@invoice)
    end

    def update
      authorize(@invoice)
      if @invoice.update(invoice_params)
        flash[:notice] = t('invoice_updated', scope: %i[billing object_invoices])
        redirect_to billing_workspace_invoice_path(@workspace, @invoice)
      else
        render :edit
      end
    end

    def destroy
      authorize(@invoice)
      if @invoice.destroy
        flash.notice = t('invoice_deleted', scope: %i[billing object_invoices])
      else
        flash[:danger] = t('invoice_cannot_be_deleted', scope: %i[billing object_invoices])
      end
      redirect_to billing_workspace_invoices_path(@workspace)
    end

    def send_to_payer
      authorize(@invoice)

      if @invoice.send_payment!
        flash.notice = t('invoice_sent_to_payer', scope: %i[billing object_invoices])
      else
        flash[:warning] = t('problem_seding_invoice_to_payer', scope: %i[billing object_invoices])
      end
      redirect_to billing_workspace_invoices_path(@workspace)
    end

    def mark_as_paid
      authorize(@invoice)

      if @invoice.pay!
        flash.notice = t('invoice_paid', scope: %i[billing object_invoices])
      else
        flash[:warning] = t('problem_marking_paid', scope: %i[billing object_invoices])
      end
      redirect_to billing_workspace_invoices_path(@workspace)
    end

    def download
      authorize(@invoice)

      PdfGeneratorService.new(ObjectInvoiceTemplate, invoice: @invoice).then do |service|
        send_data(
          service.create,
          filename: "invoice_#{Time.zone.today}.pdf",
          type: 'application/pdf'
        )
      end
    end

    def resend_invoice
      authorize(@invoice)

      ObjectInvoiceMailer.notify(@invoice).deliver_later
      flash[:notice] = t('invoice_sent_to_confed_mail', scope: %i[billing object_invoices])
      redirect_to billing_workspace_invoice_path(@workspace, @invoice)
    end

    private

    def set_workspace
      @workspace = Workspace.find(params[:workspace_id])
    end

    def set_invoice
      @invoice = @workspace.object_invoices.find(params[:id])
    end

    def invoice_params
      params.require(:billing_object_invoice).permit(
        :contract_id, :property_id, :number, :reference_number, :invoice_date, :due_date, :comment, :rounding,
        :recipient_name, :recipient_address, :recipient_personal_code, :recipient_register_code, :recipient_email,
        :recipient_phone, :custom_recipient,
        rows_attributes: %i[id cost_type description amount unit unit_price vat _destroy]
      )
    end
  end
end
