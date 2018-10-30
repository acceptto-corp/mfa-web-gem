![Acceptto](/Acceptto.png "Acceptto")

# Acceptto
Acceptto is a Multi-Factor Authentication service that allows the use of your mobile device for authorizing requested logins. A notification in the form of SMS or Push is sent to your registered device, giving you full control to authorize or decline the logins.

## Installation

Add this line to your application's Gemfile:

    gem 'acceptto', :github => 'acceptto-corp/mfa-web-gem', :branch => 'master'

And then execute:

    $ bundle install

## Usage

1- Add two fields to your user model:

    add_column :users, :mfa_access_token, :string
    add_column :users, :mfa_authenticated, :boolean

2- Add Following config variables to your config/environment/development.yml (or desired environment):

    config.mfa_app_uid = 'application unique id you got from acceptto'
    config.mfa_app_secret = 'mfa app secret you got from acceptto'
    config.mfa_site = 'https://mfa.acceptto.com'

3- you can give users an option two enable multi factor authentication with this link for example in your view:

    <% if !current_user.mfa_access_token.present? %>
       <a href='<%= "#{Rails.configuration.mfa_site}/mfa/email?uid=#{Rails.configuration.mfa_app_uid}" %>'>Enable MFA</a>
    <% end %>

4- add the route for callback/check controller in routes.rb:

    devise_for :users, controllers: { sessions: "sessions" }
    devise_scope :user do
      match '/auth/mfa_check',    to: 'sessions#mfa_check',   via: :get
      match '/auth/mfa/callback', to: 'sessions#callback', via: :get
    end

5- Add a  before_action to you application_controller.rb:

    before_action :check_mfa_authenticated

    private

    # this check is extremely important, without this after doing login and before device accept (from mfa/index.html), user can go anywhere without mfa_authentication!
    def check_mfa_authenticated
      if current_user.present? && !current_user.mfa_access_token.blank? && !current_user.mfa_authenticated?
        sign_out(current_user)
        redirect_to root_url, notice: 'MFA Two Factor Authenication required'
      end
    end


6- Implement oauth create/callback/check functions in your sessions_controller:

	class SessionsController < Devise::SessionsController
	  skip_before_action :check_mfa_authenticated

	  def create
	      resource = warden.authenticate!(auth_options)
	      if resource.mfa_access_token.present?
	              resource.update_attribute(:mfa_authenticated, false)
	            acceptto = Acceptto::Client.new(Rails.configuration.mfa_app_uid, Rails.configuration.mfa_app_secret,"#{request.protocol + request.host_with_port}/auth/mfa/callback")
	            @channel = acceptto.authenticate(resource.mfa_access_token, "Acceptto is wishing to authorize", "Login", {:ip_address => request.ip, :remote_ip_address => request.remote_ip})
	            session[:channel] = @channel
	            callback_url = "#{request.protocol + request.host_with_port}/auth/mfa_check"
	            redirect_url = "#{Rails.configuration.mfa_site}/mfa/index?channel=#{@channel}&callback_url=#{callback_url}"
	            return redirect_to redirect_url
	      else
	            set_flash_message(:notice, :signed_in) if is_navigational_format?
	            sign_in(resource_name, resource)
	            respond_with(resource, location:root_path) do |format|
	              format.json { render json: resource.as_json(root: false).merge(success: true), status: :created }
	            end
	      end

	      rescue OAuth2::Error => ex # User has deleted their access token on M2M server
	            resource.update_attribute(:mfa_access_token, nil)
	      redirect_to root_path, notice: "You have unauthorized MFA access to Acceptto, you will need to Authorize MFA again."
	  end

	  def mfa_callback
	      if params[:error].present?
	         return redirect_to root_url, notice: params[:error]
	      end

	      if params[:access_token].blank?
	          return redirect_to root_url, notice: 'Invalid parameters!'
	      end

	      if current_user.nil?
	          sign_out(current_user)
	          return redirect_to root_url, notice: 'Your session timed out, please sign-in again!'
	      end

	      current_user.update_attribute(:mfa_access_token, params[:access_token])
	      current_user.update_attribute(:mfa_authenticated, true)
	      return redirect_to root_url, notice: 'Enabling Multi Factor Authentication was successful!'
	  end


	  def mfa_check
	      if current_user.nil?
	          redirect_to root_url, notice: 'MFA Two Factor Authentication request timed out with no response.'
	      end

	      acceptto = Acceptto::Client.new(Rails.configuration.mfa_app_uid,Rails.configuration.mfa_app_secret,Rails.configuration.mfa_call_back_url)
	      status = acceptto.mfa_check(current_user.mfa_access_token,params[:channel])

	      if status == 'approved'
	          current_user.update_attribute(:mfa_authenticated, true)
	          redirect_to root_url, notice: 'MFA Two Factor Authentication request was accepted.'
	      elsif status == 'rejected'
	          current_user.update_attribute(:mfa_authenticated, false)
	          sign_out(current_user)
	          redirect_to root_url, notice: 'MFA Two Factor Authentication request was declined.'
	      else
	          redirect_to :controller => 'mfa', :action => 'index', :channel => params[:channel]
	      end
	  end
	end