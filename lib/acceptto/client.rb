require 'oauth2'

module Acceptto
  class Client

    include ActionController::Helpers
    include ActionController::Cookies

    def self.M2M_SITE
      Rails.configuration.respond_to?(:mfa_site) ? Rails.configuration.mfa_site : 'https://mfa.acceptto.com'
    end

    attr_reader :app_uid, :app_secret,:call_back_url
    def initialize(app_uid, app_secret, call_back_url)
      @app_uid = app_uid
      @app_secret = app_secret
      @call_back_url = call_back_url
    end

    def authorize_link
      "#{Acceptto::Client.M2M_SITE}/mfa/email?uid=#{@app_uid}&callback_url=#{@call_back_url}"
    end

    def get_token(authorization_code)
      access = oauth_client.auth_code.get_token(authorization_code, :redirect_uri => @call_back_url)
      access.token unless access.nil?
    end

    def authenticate(access_token, auth_message, mfa_type, cookies, options={})
      result = ''
      options[:type] = mfa_type
      options[:message] = auth_message
      options[:hash1] = cookies[:hash1] if cookies[:hash1]
      options[:hash2] = cookies[:hash2] if cookies[:hash2]
      options[:hash3] = cookies[:hash3] if cookies[:hash3]
      options[:hash4] = cookies[:hash4] if cookies[:hash4]
      access = OAuth2::AccessToken.from_hash(oauth_client, {:access_token =>  access_token})
      response = access.post('/api/v8/authenticate', :params => options ).parsed
      result = response['channel'] unless response.blank?
      result
    end

    def mfa_check(access_token,channel)
      result = ''

      access = OAuth2::AccessToken.from_hash(oauth_client, {:access_token => access_token})
      response = access.post('/api/v8/check', { :body => {:channel => channel}}).parsed

      result = response['status'] unless response.blank?

      result
    end

    def self.faye_server_address
      Rails.configuration.respond_to?(:faye_address) ? Rails.configuration.faye_address : 'https://faye.acceptto.com/faye'
    end

    private

    def oauth_client
      @oauth_client ||= OAuth2::Client.new(@app_uid,@app_secret, :site => Acceptto::Client.M2M_SITE)
    end
  end
end
