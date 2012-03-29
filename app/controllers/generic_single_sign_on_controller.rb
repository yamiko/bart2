class GenericSingleSignOnController < ApplicationController

	def get_token
		user = User.authenticate(params[:login], params[:password]) rescue nil
		sign_in(:user, user) if user
		authenticate_user! if user
		user_token = nil
		if !user.blank?
			current_user.reset_authentication_token
			user_token = current_user.authentication_token
			render :json => {:auth_token => current_user.authentication_token }.to_json, :status => :ok
		else
			render :json => {:auth_token => '' }.to_json, :status => :false
		end
	end

	def single_sign_in
		session[:return_uri] = params[:return_uri]
		redirect_to params[:destination_uri]
		return
	end

end
