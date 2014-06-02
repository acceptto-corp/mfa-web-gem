require 'oauth2'

module Acceptto
  class Client
    M2M_SITE = (defined?(Rails.configuration.mfa_site).nil?) ? 'https://mfa.acceptto.com' : Rails.configuration.mfa_site

    attr_reader :app_uid, :app_secret,:call_back_url
    def initialize(app_uid, app_secret, call_back_url)
      @app_uid = app_uid
      @app_secret = app_secret
      @call_back_url = call_back_url
      p "Rails.configuration.mfa_site: #{Rails.configuration.mfa_site}"
      p "M2M_SITE value is: #{M2M_SITE}"
    end

    def authorize_link
      "#{M2M_SITE}/mfa/email?uid=#{@app_uid}"
    end

    def get_token(authorization_code)
      access = oauth_client.auth_code.get_token(authorization_code, :redirect_uri => @call_back_url)
      access.token unless access.nil?
    end

    def authenticate(access_token, auth_message, mfa_type)
      result = ''

      access = OAuth2::AccessToken.from_hash(oauth_client, {:access_token =>  access_token})
      response = access.post('/api/v4/authenticate', :params => {:message => auth_message, :meta_data => {:type => mfa_type}}).parsed
      result = response['channel'] unless response.blank?

      result
    end

    def mfa_check(access_token,channel)
      result = ''

      access = OAuth2::AccessToken.from_hash(oauth_client, {:access_token => access_token})
      response = access.post('/api/v4/check', { :body => {:channel => channel}}).parsed

      result = response['status'] unless response.blank?

      result
    end

    def self.faye_server_address
      if defined? Rails.configuration.faye_address 
        Rails.configuration.faye_address 
      else
        'https://faye.acceptto.net/faye'
      end
    end

    private

    def oauth_client
      @oauth_client ||= OAuth2::Client.new(@app_uid,@app_secret, :site => M2M_SITE)
    end
  end
end
