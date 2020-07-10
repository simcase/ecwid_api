require "open-uri"

module EcwidApi
  # Public: Client objects manage the connection and interface to a single Ecwid
  # store.
  #
  # Examples
  #
  #   client = EcwidApi::Client.new(store_id: '12345', token: 'the access_token')
  #   client.get "/products"
  #
  class Client
    extend Forwardable

    # The default base URL for the Ecwid API
    DEFAULT_URL = "https://app.ecwid.com/api/v3"

    # Public: Returns the Ecwid Store ID
    attr_reader :store_id
    attr_reader :token
    attr_reader :adapter

    attr_reader :connection, :categories, :orders, :products, :profile

    # Public: Initializes a new Client to interact with the API
    #
    # store_id - the Ecwid store_id to interact with
    # token    - the authorization token provided by oAuth. See the
    #            Authentication class
    #
    def initialize(store_id, token, options={})
      options[:adapter] ||= Faraday.default_adapter
      @store_id, @token, @adapter = store_id, token, options[:adapter]

      @connection = Faraday.new store_url do |conn|
        conn.request  :oauth2, token, param_name: :token, token_type: :param
        conn.request  :json

        conn.response :json, content_type: /\bjson$/
        conn.response :logger if options[:response_logging]

        conn.options[:open_timeout] = 3
        conn.options[:timeout] = 6

        conn.adapter  options[:adapter]
      end

      @categories = Api::Categories.new(self)
      @orders     = Api::Orders.new(self)
      @products   = Api::Products.new(self)
      @profile    = Api::Profile.new(self)
    end

    # Public: The URL of the API for the Ecwid Store
    def store_url
      "#{DEFAULT_URL}/#{store_id}"
    end

    def get(*args, &block)
      raise_on_failure connection.get(*args, &block)
    end

    def post(*args, &block)
      raise_on_failure connection.post(*args, &block)
    end

    def put(*args, &block)
      raise_on_failure connection.put(*args, &block)
    end

    def delete(*args, &block)
      raise_on_failure connection.delete(*args, &block)
    end

    # Public: A helper method for POSTing an image
    #
    # url - the URL to POST the image to
    # filename - the path or URL to the image to upload
    #
    # Returns a Faraday::Response
    #
    def post_image(url, filename)
      post(url) do |req|
        req.body = open(filename).read
      end
    end

    private

    # Private: Raises a ResponseError if the request failed
    #
    # response - a Faraday::Response object that is the result of a request
    #
    # Raises ResponseError if the request wasn't successful
    #
    # Returns the original response if the request was successful
    #
    #
    def raise_on_failure(response)
      if response.success?
        if response.body.is_a?(Hash) && response.body["updateCount"] &&
           response.body["updateCount"] != 1
          raise UpdateError.new(response)
        end
        response
      else
        raise ResponseError.new(response)
      end
    end
  end
end
