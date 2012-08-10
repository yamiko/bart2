class GenericSingleSignOnController < ApplicationController

	def get_token
		user = User.authenticate(params[:login], params[:password]) rescue nil
		sign_in(:user, user) if user
		authenticate_user! if user
		user_token = nil
		if !user.blank?
			current_user.reset_authentication_token
			user_token = current_user.authentication_token
			current_user.save!
			render :json => {:auth_token => current_user.authentication_token }.to_json, :status => :ok
		else
			render :json => {:auth_token => '' }.to_json, :status => :false
		end
	end

	def single_sign_in

		if params["return_uri"].blank?
			session[:return_uri] = '/'
		else
			session[:return_uri] = params["return_uri"]
		end

    session[:datetime] = params["current_time"].to_time rescue Time.now

		self.current_location = (Location.find(params["current_location"].to_i) rescue nil)
    
		if self.current_location.blank? || self.current_location.nil?      
			location_required
		elsif params["destination_uri"].blank?
			redirect_to '/' + "?location=#{params["current_location"]}"  and return
		else
			redirect_to params["destination_uri"] + (!params["destination_uri"].index("?").nil? ?
          "&location=#{params["current_location"]}" : "") and return
		end
		return
	end

end
