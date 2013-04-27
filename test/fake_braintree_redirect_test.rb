require 'pry'
require 'rack/test'
require 'fake_braintree_redirect'
require 'minitest/autorun'
require 'braintree'
# Needs to be defined so that hash parameter can be correctly defined
Braintree::Configuration.environment = :sandbox
Braintree::Configuration.merchant_id = "fake"
Braintree::Configuration.public_key = "fake"
Braintree::Configuration.private_key = "fake"

class DummyApp
  def call(env)
    [200, {}, ["OK"]]
  end
end


describe FakeBraintreeRedirect do
  include Rack::Test::Methods

  def app
    app = Rack::Builder.new do
      use FakeBraintreeRedirect
      map "/" do
        run DummyApp.new
      end
    end
  end

  def env
    { "SERVER_NAME" => "sandbox.braintreegateway.com" }
  end

  def transaction_tr_data
    {
      :api_version => '3',
      :kind => "create_transaction",
      :public_key => "fake",
      :redirect_url => "http://example.com/braintree",
      :time => Time.now.strftime("%Y%m%d%H%M%s"),
      :transaction => {
        :amount => "19.95",
        :type => "sale"
      }
    }
  end

  def transaction_data(tr_data=transaction_tr_data())
    {
      :transaction => {
        :customer => {
          :first_name => "Test",
          :last_name  => "User"
        },
        :credit_card => {
          :number => "4111111111111111",
          :expiration_date => "5/2014",
          :cvv => "123"
        }
      },
      :tr_data => "fake|#{Rack::Utils.build_nested_query(tr_data)}"
    }
  end

  def credit_card_tr_data
    {
      :api_version => '3',
      :kind => "create_payment_method",
      :public_key => "fake",
      :redirect_url => "http://example.com/braintree",
      :time => Time.now.strftime("%Y%m%d%H%M%s"),
      :credit_card => {
        :customer_id => "1",
      }
    }
  end

  def credit_card_data
    {
      :credit_card => {
        :number => "4111111111111111",
        :expiration_date => "5/2014",
        :cvv => "123"
      },
      :tr_data => "fake|#{Rack::Utils.build_nested_query(credit_card_tr_data)}"
    }
  end

  it "makes a successful transaction request" do
    post '/merchants/fake/transparent_redirect_requests', transaction_data, env
    last_response.status.must_equal 303

    location = last_response.headers["Location"]
    location.must_include transaction_tr_data[:redirect_url]

    query = Rack::Utils.parse_query(location.split("?").last)
    query["http_status"].must_equal "200"
    query["id"].must_equal "a_fake_id"
    query["kind"].must_equal "create_transaction"
    query["hash"].length.must_equal 40
  end

  it "makes a successful credit card request" do
    post '/merchants/fake/transparent_redirect_requests', credit_card_data, env
    last_response.status.must_equal 303

    location = last_response.headers["Location"]
    location = last_response.headers["Location"]
    location.must_include credit_card_tr_data[:redirect_url]

    query = Rack::Utils.parse_query(location.split("?").last)
    query["http_status"].must_equal "200"
    query["id"].must_equal "a_fake_id"
    query["kind"].must_equal "create_payment_method"
    query["hash"].length.must_equal 40
  end

  it "works with redirect_urls that contain query parameters" do
    new_tr_data = transaction_tr_data.clone
    new_tr_data[:redirect_url] = "http://example.com/braintree?plan_id=1"
    post '/merchants/fake/transparent_redirect_requests', transaction_data(new_tr_data), env
    last_response.status.must_equal 303
    location = last_response.headers["Location"]
    location.must_include transaction_tr_data[:redirect_url]

    query = Rack::Utils.parse_query(location.split("?").last)
    query["http_status"].must_equal "200"
    query["id"].must_equal "a_fake_id"
    query["kind"].must_equal "create_transaction"
    query["hash"].length.must_equal 40
    query["plan_id"].must_equal "1"
  end

  it "falls back to main app when not POST" do
    get '/merchants/fake/transparent_redirect_requests', transaction_data, env
    last_response.status.must_equal 404
  end

  it "falls back to main app when not requesting sandbox" do
    new_env = env.clone
    new_env["SERVER_NAME"] = "example.com"
    post '/merchants/fake/transparent_redirect_requests', transaction_data, new_env
    last_response.status.must_equal 404
  end

end
