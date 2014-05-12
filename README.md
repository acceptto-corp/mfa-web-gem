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

    add_column :users, :m2m_access_token, :string
    add_column :users, :m2m_authenticated, :boolean

2- Add Following Environment Variables to your config/application.yml:

    # M2M ENVs
    M2M_APP_ID: your application unique identifier you recieved after registration.
    M2M_CALLBACK_URL: http://localhost:3000/auth/m2m/callback
    M2M_SECRET: 96a6b653b42af4222c0f605c92ba856c73fed60b9f10af6f941ea31c12fa9a56

3- add config/initializers/m2m.rb:

    yaml_data = YAML::load(ERB.new(IO.read(File.join(Rails.root, 'config', 'application.yml'))).result)
    APP_CONFIG = HashWithIndifferentAccess.new(yaml_data)

4- you can give users an option two enable multi facto authorization with this link for example in your view:

    <% if !current_user.m2m_access_token.present? %>
       <a href="<%= current_user.m2m_authorize_link %>">Enable MFA</a>
    <% end %>

5- add the route for callback/check controller in routes.rb:

    devise_for :users, controllers: { sessions: "sessions" }
    devise_scope :user do		
      match '/auth/mfa_check',    to: 'sessions#mfa_check',   via: :get
      match '/auth/m2m/callback', to: 'sessions#callback', via: :get
    end
      
    get "mfa" => 'mfa#index'

6- Add a before_filter to you ApplicationController.rb:

    before_filter :check_m2m_authenticated

    private

    # this check is extremely important, without this after doing login and before device accept (from mfa/index.html), user can go anywhere without m2m_authentication!
    def check_m2m_authenticated
      if current_user.present? && !current_user.m2m_access_token.empty? && !current_user.m2m_authenticated?
        sign_out(current_user)
        redirect_to root_url, notice: 'MFA Two Factor Authenication required'
      end
    end


7- Implement oauth create/callback/check functions in your sessions_controller:

    class SessionsController < Devise::SessionsController
       skip_before_filter :check_m2m_authenticated
       skip_before_filter :verify_authenticity_token, :only=> :callback
	   
       def create
          resource = warden.authenticate!(auth_options)
          if resource.m2m_access_token.present?
             current_user.update_attribute(:m2m_authenticated, false)
             access = OAuth2::AccessToken.from_hash(client, {access_token: current_user.m2m_access_token})
             response = access.post("/api/v2/authenticate", params: {message: "Acceptto is wishing to authorize ",meta_data: {type: 'Login'}}).parsed
             @channel = response["channel"]
             p "got channel: #{@channel}"
             flash[:notice] = "You have 60 seconds to respond to the request sent to your device."
             redirect_to :controller => 'mfa', :action => 'index', :channel => @channel
          else
             set_flash_message(:notice, :signed_in) if is_navigational_format?
             sign_in(resource_name, resource)
             respond_with(resource, location:root_path) do |format|
                 format.json { render json: resource.as_json(root: false).merge(success: true), status: :created }
             end
          end
          rescue OAuth2::Error => ex # User has deleted their access token on M2M server
          current_user.update_attribute(:m2m_access_token, nil)
          redirect_to root_path, notice: "You have unauthorized MFA access to Acceptto, you will need to Authorize MFA again."
       end
	   
       def mfa_check
          if current_user.nil?
              redirect_to root_url, notice: 'MFA Two Factor Authentication request timed out with no response.'
          end
          access = OAuth2::AccessToken.from_hash(client, {:access_token => current_user.m2m_access_token })
          Rails.logger.error '----------------------'
          Rails.logger.error access.inspect
          response = access.post("/api/v2/check", { body: {:channel => params[:channel]} }).parsed
          Rails.logger.error response.inspect
          if response["status"] == "approved"
               current_user.update_attribute(:m2m_authenticated, true)
               redirect_to root_url, notice: 'MFA Two Factor Authentication request was accepted.'
          elsif response["status"] == "rejected"
               sign_out(current_user)
               redirect_to root_url, notice: 'MFA Two Factor Authentication request was declined.'
          else
               sign_out(current_user)
               redirect_to root_url, notice: 'MFA Two Factor Authentication request timed out with no response.'
          end
       end
	   
       def callback
          access = client.auth_code.get_token(params[:code], redirect_uri: APP_CONFIG['M2M_CALLBACK_URL'])
          current_user.update_attribute(:m2m_access_token, access.token)
          current_user.update_attribute(:m2m_authenticated, true)
          redirect_to root_url, notice: "MFA Access Granted"
       end
	   
       private
	   
       def client
          @client ||= OAuth2::Client.new(APP_CONFIG['M2M_APP_ID'], APP_CONFIG['M2M_SECRET'], site: APP_CONFIG['M2M_SITE'])
       end
	   
    end

8- Create a new controller/view named: app/controllers/mfa_controller.rb and app/views/mfa/index.html.erb, content of mfa/index.html.rb:
	
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
	
10- Add javascript for faye to your head section in layout of your website:

	<%= javascript_include_tag "#{APP_CONFIG['FAYE_SERVER']}/faye.js", "data-turbolinks-track" => false %>





## Contributing

1. Fork it ( http://github.com/<my-github-username>/Acceptto/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
