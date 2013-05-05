module AngelEdPaypalExpress
  module Processors
    class Paypal

      def process!(donation, data)
        status = data["checkout_status"] || "pending"

        Rails.logger.debug "PAYPAL PROCESSOR: donation->" + donation.inspect() + "data->" + data.inspect()

        notification = donation.payment_notifications.new({
          extra_data: data
        })

        Rails.logger.debug "PAYPAL PROCESSOR NOTIFICATION: " + notification.inspect()
        notification.save!

        donation.confirm! if success_payment?(status)
      rescue Exception => e
        ::Airbrake.notify({ :error_class => "Paypal Processor Error", :error_message => "Paypal Processor Error: #{e.inspect}", :parameters => data}) rescue nil
      end

      protected

      def success_payment?(status)
        status == 'PaymentActionCompleted'
      end

    end
  end
end
