require 'angel_ed_paypal_express/processors'

module AngelEdPaypalExpress::Payment
  class PaypalExpressController < ApplicationController
    skip_before_filter :verify_authenticity_token, :only => [:notifications]
    skip_before_filter :detect_locale, :only => [:notifications]
    skip_before_filter :set_locale, :only => [:notifications]
    skip_before_filter :force_http

    before_filter :setup_gateway

    SCOPE = "donations.checkout"

    layout :false

    def review

    end

    def ipn
      donation = Donation.where(:payment_id => params['txn_id']).first
      if donation
        notification = donation.payment_notifications.new({
          extra_data: JSON.parse(params.to_json.force_encoding(params['charset']).encode('utf-8'))
        })
        notification.save!
        donation.update_attributes({
          :payment_service_fee => params['mc_fee'],
          :payer_email => params['payer_email']
        })
      end
      return render status: 200, nothing: true
    rescue Exception => e
      ::Airbrake.notify({ :error_class => "Paypal Notification Error", :error_message => "Paypal Notification Error: #{e.inspect}", :parameters => params}) rescue nil
      return render status: 200, nothing: true
    end

    def notifications
      donation = Donation.find params[:id]
      response = @@gateway.details_for(donation.payment_token)

      Rails.logger.debug "NOTIFICATION: " + response.inspect()

      if response.params['transaction_id'] == params['txn_id']
        build_notification(donation, response.params)
        render status: 200, nothing: true
      else
        render status: 404, nothing: true
      end
    rescue Exception => e
      ::Airbrake.notify({ :error_class => "Paypal Notification Error", :error_message => "Paypal Notification Error: #{e.inspect}", :parameters => params}) rescue nil
      render status: 404, nothing: true
    end

    def pay
      donation = Donation.find params[:id]

      donation.update_attribute :donation_amount, params[:user_document] if params[:user_document].present?


      begin
        response = @@gateway.setup_purchase(donation.price_in_cents, {
          ip: request.remote_ip,
          return_url: payment_success_paypal_express_url(id: donation.id),
          cancel_return_url: payment_cancel_paypal_express_url(id: donation.id),
          currency_code: 'USD',
          description: donation.paypal_description,
          notify_url: payment_notifications_paypal_express_url(id: donation.id)
        })

        donation.update_attribute :payment_method, 'PayPal'
        donation.update_attribute :payment_token, response.token

        build_notification(donation, response.params)

        redirect_to @@gateway.redirect_url_for(response.token)
      rescue Exception => e
        ::Airbrake.notify({ :error_class => "Paypal Error", :error_message => "Paypal Error: #{e.inspect}", :parameters => params}) rescue nil
        Rails.logger.info "-----> #{e.inspect}"
        paypal_flash_error
        return redirect_to main_app.edit_donation_path(donation)
      end
    end

    def success
      donation = Donation.find params[:id]
      begin
        @@gateway.purchase(donation.price_in_cents, {
          ip: request.remote_ip,
          token: donation.payment_token,
          payer_id: params[:PayerID]
        })

        # we must get the deatils after the purchase in order to get the transaction_id
        details = @@gateway.details_for(donation.payment_token)

        build_notification(donation, details.params)

        if details.params['transaction_id'] 
          donation.update_attribute :payment_id, details.params['transaction_id']
        end
        paypal_flash_success
        redirect_to main_app.donation_path(id: donation.id)
      rescue Exception => e
        ::Airbrake.notify({ :error_class => "Paypal Error", :error_message => "Paypal Error: #{e.message}", :parameters => params}) rescue nil
        Rails.logger.info "-----> #{e.inspect}"
        paypal_flash_error
        return redirect_to main_app.edit_donation_path(donation.id)
      end
    end

    def cancel
      donation = Donation.find params[:id]
      flash[:failure] = t('paypal_cancel', scope: SCOPE)
      redirect_to main_app.edit_donation_path(donation.id)
    end

  private

    def build_notification(donation, data)
      processor = AngelEdPaypalExpress::Processors::Paypal.new
      processor.process!(donation, data)
    end

    def paypal_flash_error
      flash[:failure] = t('paypal_error', scope: SCOPE)
    end

    def paypal_flash_success
      flash[:success] = t('success', scope: SCOPE)
    end

    def setup_gateway
      if ::Configuration[:paypal_username] and ::Configuration[:paypal_password] and ::Configuration[:paypal_signature]
        @@gateway ||= ActiveMerchant::Billing::PaypalExpressGateway.new({
          :login => ::Configuration[:paypal_username],
          :password => ::Configuration[:paypal_password],
          :signature => ::Configuration[:paypal_signature]
        })
      else
        puts "[PayPal] An API Certificate or API Signature is required to make requests to PayPal"
      end
    end
  end
end
