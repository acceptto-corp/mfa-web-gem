![Acceptto](/Acceptto.png "Acceptto")

# Acceptto

Acceptto mfa-web-gem enables multi-factor authentication for your applications and services.

## Installation

Add this line to your application's Gemfile:

    gem 'Acceptto'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install Acceptto

## Usage

1- Add two fields to your user model:

    add_column :users, :mfa_access_token, :string
    add_column :users, :mfa_authenticated, :boolean

2- Add Following config variables to your config/environment/development.yml (or desired environment):

    config.mfa_app_uid = 'application unique id you got from acceptto'
    config.mfa_app_secret = 'mfa app secret you got from acceptto'
    config.mfa_call_back_url = 'put your callback url here'

3- you can give users an option two enable multi facto authentication with this link for example in your view:

    <% if !current_user.mfa_access_token.present? %>
       <a href="><%= Acceptto::Client.new(Rails.configuration.mfa_app_uid,Rails.configuration.mfa_app_secret,Rails.configuration.mfa_call_back_url).authorize_link %>">Enable MFA</a>
    <% end %>

4- add the route for callback/check controller in routes.rb:

    devise_for :users, controllers: { sessions: "sessions" }
    devise_scope :user do
      match '/auth/mfa_check',    to: 'sessions#mfa_check',   via: :get
      match '/auth/mfa/callback', to: 'sessions#callback', via: :get
    end

    get "mfa" => 'mfa#index'

5- Add a before_filter to you ApplicationController.rb:

    before_filter :check_mfa_authenticated

    private

    # this check is extremely important, without this after doing login and before device accept (from mfa/index.html), user can go anywhere without mfa_authentication!
    def check_mfa_authenticated
      if current_user.present? && !current_user.mfa_access_token.empty? && !current_user.mfa_authenticated?
        sign_out(current_user)
        redirect_to root_url, notice: 'MFA Two Factor Authenication required'
      end
    end


6- Implement oauth create/callback/check functions in your sessions_controller:

    class SessionsController < Devise::SessionsController
    skip_before_filter :check_mfa_authenticated

    def create
        resource = warden.authenticate!(auth_options)
        if resource.mfa_access_token.present?
            current_user.update_attribute(:mfa_authenticated, false)
            acceptto = Acceptto::Client.new(Rails.configuration.mfa_app_uid,Rails.configuration.mfa_app_secret,Rails.configuration.mfa_call_back_url)
            @channel = acceptto.authenticate(resource.mfa_access_token)
            flash[:notice] = 'You have 60 seconds to respond to the request sent to your device.'

            redirect_to :controller => 'mfa', :action => 'index', :channel => @channel
        else
            sign_in(resource_name, resource)
            respond_with(resource, location:root_path) do |format|
                format.json { render json: resource.as_json(root: false).merge(success: true), status: :created }
            end
        end
    rescue OAuth2::Error => ex
        current_user.update_attribute(:mfa_access_token, nil)
        redirect_to root_path, notice: 'You have unauthorized MFA access to Acceptto, you will need to Authorize MFA again.'
    end

    def mfa_callback
        acceptto = Acceptto::Client.new(Rails.configuration.mfa_app_uid,Rails.configuration.mfa_app_secret,Rails.configuration.mfa_call_back_url)
        token = acceptto.get_token(params[:code])
        current_user.update_attribute(:mfa_access_token, token)
        current_user.update_attribute(:mfa_authenticated, true)

        redirect_to root_url, notice: "MFA Access Granted #{token}"
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

7- Create a new controller/view named: app/controllers/mfa_controller.rb and app/views/mfa/index.html.erb, content of mfa/index.html.rb:

	<script type="text/javascript">
    $(function() {
        var faye = new Faye.Client("<%= APP_CONFIG['FAYE_SERVER'] %>");
        faye.subscribe("/messages/<%= @channel %>", function(data) {
            window.location.replace("/auth/mfa_check?channel=<%= @channel %>");
        });

        var now = new Date();

        var target_date = new Date(now.getTime() + 60000);

        // variables for time units
        var days, hours, minutes, seconds;

        // get tag element
        var countdown = document.getElementById("notice");
        var notice_text = countdown.innerHTML

        // update the tag with id "countdown" every 1 second
        setInterval(function () {

            // find the amount of "seconds" between now and target
            var current_date = new Date().getTime();
            var seconds_left = (target_date - current_date) / 1000;

            // do some time calculations
            days = parseInt(seconds_left / 86400);
            seconds_left = seconds_left % 86400;

            hours = parseInt(seconds_left / 3600);
            seconds_left = seconds_left % 3600;

            minutes = parseInt(seconds_left / 60);
            seconds = parseInt(seconds_left % 60);

            if (seconds == 0) {
                window.location.replace("/auth/mfa_check?channel=<%= @channel %>");
            }

            if (seconds <= 0) {
                seconds = 0;
            }

            // format countdown string + set tag value
            countdown.innerHTML = notice_text + " : " + days + "d, " + hours + "h, "
                    + minutes + "m, " + seconds + "s";

        }, 1000);

 	   });
	</script>

8- Add javascript for faye to your head section in layout of your website:

	<%= javascript_include_tag "#{APP_CONFIG['FAYE_SERVER']}/faye.js", "data-turbolinks-track" => false %>


