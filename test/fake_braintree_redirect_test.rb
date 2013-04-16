require 'pry'
require 'rack/test'
require 'fake_braintree_redirect'
require 'minitest/autorun'

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

  def tr_data
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

  def transaction_data(tr_data=tr_data())
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

  it "makes a successful request" do
    post '/merchants/fake/transparent_redirect_requests', transaction_data, env
    last_response.status.must_equal 303
    uri = URI.parse(tr_data[:redirect_url])
    query = {
      :http_status => 202,
      :id => "a_fake_id",
      :kind => "create_transaction",
      :hash => "a_fake_hash"
    }
    uri.query = Rack::Utils.build_query(query)
    last_response.headers["Location"].must_equal uri.to_s
  end

  it "works with redirect_urls that contain query parmaeters" do
    new_tr_data = tr_data.clone
    new_tr_data[:redirect_url] = "http://example.com/braintree?plan_id=1"
    post '/merchants/fake/transparent_redirect_requests', transaction_data(new_tr_data), env
    last_response.status.must_equal 303
    uri = URI.parse(tr_data[:redirect_url])
    query = {
      :plan_id => 1,
      :http_status => 202,
      :id => "a_fake_id",
      :kind => "create_transaction",
      :hash => "a_fake_hash"
    }
    uri.query = Rack::Utils.build_query(query)
    last_response.headers["Location"].must_equal uri.to_s
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
