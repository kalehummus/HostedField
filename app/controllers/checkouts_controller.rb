class CheckoutsController < ApplicationController
  TRANSACTION_SUCCESS_STATUSES = [
    Braintree::Transaction::Status::Authorizing,
    Braintree::Transaction::Status::Authorized,
    Braintree::Transaction::Status::Settled,
    Braintree::Transaction::Status::SettlementConfirmed,
    Braintree::Transaction::Status::SettlementPending,
    Braintree::Transaction::Status::Settling,
    Braintree::Transaction::Status::SubmittedForSettlement,
  ]

  def new
    @client_token = gateway.client_token.generate
  end

  def show
    @transaction = gateway.transaction.find(params[:id])
    @result = _create_result_hash(@transaction)
  end

  def create
    amount = params["amount"] # In production you should not take amounts directly from clients

    nonce = params["payment_method_nonce"]

    result = gateway.customer.create(
      :payment_method_nonce => nonce,
      # :first_name => "",
      # :last_name => "table",
      :credit_card => {
        :options => {
          :verify_card => true
        }
      }
    )
    if result.success?
      # puts result.customer.id
      the_token = result.customer.payment_methods[0].token
      result = gateway.transaction.sale(
        amount: amount,
        payment_method_token: the_token,
        :options => {
          :submit_for_settlement => true
        }
      )

      if result.success? || result.transaction
        redirect_to checkout_path(result.transaction.id)
      else
        error_messages = result.errors.map { |error| "Error: #{error.code}: #{error.message}" }
        flash[:error] = error_messages
        redirect_to new_checkout_path
      end
    else
      # p result
      verification = result.credit_card_verification
      # p verification.status
      # START HERE!!!!!!!!
      error_messages = "The verification status is " + verification.status + ". Please try a different card."
      # error_messages = "Please try a different card."
      # error_messages = result.errors.map { |error| "Error: #{verification.status}" }
      flash[:error] = error_messages
      redirect_to new_checkout_path

    end

    # result = gateway.transaction.sale(
    #   amount: amount,
    #   payment_method_token: the_token,
    #   :options => {
    #     :submit_for_settlement => true
    #   }
    # )
    #
    # if result.success? || result.transaction
    #   redirect_to checkout_path(result.transaction.id)
    # else
    #   error_messages = result.errors.map { |error| "Error: #{error.code}: #{error.message}" }
    #   flash[:error] = error_messages
    #   redirect_to new_checkout_path
    # end

  end











  def _create_result_hash(transaction)
    status = transaction.status

    if TRANSACTION_SUCCESS_STATUSES.include? status
      result_hash = {
        :header => "Sweet Success!",
        :icon => "success",
        :message => "Your test transaction has been successfully processed. See the Braintree API response and try again."
      }
    else
      result_hash = {
        :header => "Transaction Failed",
        :icon => "fail",
        :message => "Your test transaction has a status of #{status}. See the Braintree API response and try again."
      }
    end
  end

  def gateway
    env = ENV["BT_ENVIRONMENT"]

    @gateway ||= Braintree::Gateway.new(
      :environment => env && env.to_sym,
      :merchant_id => ENV["BT_MERCHANT_ID"],
      :public_key => ENV["BT_PUBLIC_KEY"],
      :private_key => ENV["BT_PRIVATE_KEY"],
    )
  end
end
