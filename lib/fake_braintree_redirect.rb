require 'rack'
require 'uri'
class FakeBraintreeRedirect
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    if env['SERVER_NAME'] == "api.sandbox.braintreegateway.com" && request.post?
      if /merchants\/.*?\/transparent_redirect_requests/.match(env["PATH_INFO"])
        tr_data = request.params["tr_data"]
        tr_data_params = Rack::Utils.parse_nested_query(tr_data.split("|").last)

        url = build_url(tr_data_params["redirect_url"], tr_data_params["kind"])
        headers = {}
        headers["Location"] = url.to_s

        [303, headers, ["See other"]]
      else
        @app.call(env)
      end
    else
      @app.call(env)
    end
  end

  def build_url(url, kind)
    # Massage redirect_url, add Braintree parameters.
    uri = URI.parse(url)
    existing_query = Rack::Utils.parse_nested_query(uri.query)
    query = existing_query.merge(
      :http_status => 200,
      :id => "a_fake_id",
      :kind => kind 
    )
    query_string = Rack::Utils.build_query(query)
    hash = ::Braintree::Digest.hexdigest(Braintree::Configuration.private_key, query_string)
    uri.query = Rack::Utils.build_query(query.merge(:hash => hash))
    uri
  end
end
