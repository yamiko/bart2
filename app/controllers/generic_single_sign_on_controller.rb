class GenericSingleSignOnController < ApplicationController

	def get_token
		user = User.authenticate(params[:login], params[:password])
		sign_in(:user, user)
		authenticate_user!
		user_token = nil
		if user_signed_in?
			current_user.reset_authentication_token
			user_token = current_user.authentication_token
		end
		return user_token
	end

	def single_sign_in
		session[:return_uri] = params[:return_uri]
		redirect_to params[:destination_uri]
		return
	end

end
