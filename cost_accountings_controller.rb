# frozen_string_literal: true

class Workspaces
  class PropertyGroups
    class CostAccountingsController < WorkspaceApplicationController
      layout 'application_dashkit'
      before_action :set_property_group
      before_action :set_workspace
      before_action :set_cost_accounting, except: %i[index new create]

      def index
        authorize(@property_group.cost_accountings.new)
        @cost_accountings = policy_scope(@property_group.cost_accountings)
      end

      def show
        authorize(@cost_accounting)
        @divided_costs = @cost_accounting.divided_costs.sort_by { |_key, value| value['display_name'].to_s.downcase }
                           .to_h.deep_symbolize_keys
        @grouped_divided_costs = @cost_accounting.grouped_costs
      end

      def show_property
        authorize(@cost_accounting)
        @property = @property_group.properties.find(params[:property])
        @divided_costs = @cost_accounting.divided_costs.deep_symbolize_keys
        @grouped_divided_costs = @cost_accounting.grouped_costs
      end

      def new
        @cost_accounting = @property_group.cost_accountings.build
        authorize(@cost_accounting)
      end

      def create
        @cost_accounting = @property_group.cost_accountings.build(cost_accounting_params)
        authorize(@cost_accounting)
        if @cost_accounting.save
          flash[:notice] = t('new_cost_accounting_added', scope: %i[dashkit_cost_accounting])
          redirect_to [@property_group.workspace, @property_group, @cost_accounting]
        else
          render :new
        end
      end

      def edit
        authorize(@cost_accounting)
      end

      def update
        authorize(@cost_accounting)
        if @cost_accounting.update(update_cost_accounting_params)
          flash[:notice] = t('cost_accounting_updated', scope: %i[dashkit_cost_accounting])
          redirect_to [@property_group.workspace, @property_group, @cost_accounting]
        else
          render :edit
        end
      end

      def destroy
        authorize(@cost_accounting)

        @cost_accounting.destroy!

        redirect_to [@property_group.workspace, @property_group, :cost_accountings]
      end

      def calculate
        authorize(@cost_accounting)
        if @cost_accounting.divide_costs
          flash[:notice] = t('calculate_success', scope: %i[dashkit_cost_accounting])
        else
          flash[:warning] = t('calculate_fail', scope: %i[dashkit_cost_accounting])
        end
        redirect_to [@property_group.workspace, @property_group, @cost_accounting]
      end

      def close
        authorize(@cost_accounting)
        if @cost_accounting.close
          flash[:notice] = t('cost_accounting_success_closed', scope: %i[dashkit_cost_accounting])
        else
          flash[:warning] = t('closing_cost_accounting_failed', scope: %i[dashkit_cost_accounting])
        end
        redirect_to [@property_group.workspace, @property_group, @cost_accounting]
      end

      def reopen
        authorize(@cost_accounting)
        if @cost_accounting.reopen
          flash[:notice] = t('cost_accounting_success_reopened', scope: %i[dashkit_cost_accounting])
        else
          flash[:warning] = t('reopening_cost_accounting_failed', scope: %i[dashkit_cost_accounting])
        end
        redirect_to [@property_group.workspace, @property_group, @cost_accounting]
      end

      def download_estonian_e_arve_xml
        authorize(@cost_accounting)
        respond_to do |format|
          format.xml do
            send_data(
              EstonianEArveService.new(@cost_accounting).xml,
              filename: 'estonial_e_arve.xml',
              type: 'application/xml',
              disposition: 'attachment'
            )
          end
        end
      end

      def download_property_invoice
        authorize(@cost_accounting)
        @property = @property_group.properties.find(params[:property])

        invoice = @cost_accounting.invoice_for_property(@property)

        PdfGeneratorService.new(CostAccountingInvoiceTemplate, invoice: invoice, property: @property).then do |service|
          send_data(
            service.create,
            filename: "invoice_#{Time.zone.today}.pdf",
            type: 'application/pdf'
          )
        end
      end

      def send_invoice_to_property
        authorize(@cost_accounting)
        @property = @property_group.properties.find(params[:property])

        invoice = @cost_accounting.invoice_for_property(@property)

        PropertyInvoiceMailer.notify(invoice, @property).deliver_later
        flash[:notice] = 'Invoice sent to configured email'
        redirect_to [:show_property, @property_group.workspace, @property_group, @cost_accounting, property: @property]
      end

      private

      def set_property_group
        @property_group = policy_scope(PropertyGroup).find(params[:property_group_id])
      end

      def set_cost_accounting
        @cost_accounting = @property_group.cost_accountings.find(params[:id])
      end

      def cost_accounting_params
        params.require(:cost_accounting).permit(:start_date, :end_date, :comment)
      end

      def update_cost_accounting_params
        params.require(:cost_accounting).permit(
          :start_date, :end_date, :comment, :invoice_date,
          cost_accounting_invoices_attributes: %i[cost_type_id id name amount _destroy consumption comment unit_price]
        )
      end
    end
  end
end
