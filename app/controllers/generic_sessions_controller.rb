class GenericSessionsController < ApplicationController
	skip_before_filter :authenticate_user!, :except => [:location, :update]
	skip_before_filter :location_required

	def new
	end


	def create
		user = User.authenticate(params[:login], params[:password])
		sign_in(:user, user) if user
		authenticate_user! if user

		session[:return_uri] = nil
		session[:datetime] = nil

		if user_signed_in?
			current_user.reset_authentication_token
			#my_token = current_user.authentication_token
			#User.find_for_authentication_token()
			#self.current_user = user      
			redirect_to '/clinic'
		else
			note_failed_signin
			@login = params[:login]
			render :action => 'new'
		end
	end

	# Form for entering the location information
	def location
		@login_wards = (CoreService.get_global_property_value('facility.login_wards')).split(',') rescue []
		if (CoreService.get_global_property_value('select_login_location').to_s == "true" rescue false)
			render :template => 'sessions/select_location'
		end

    @stock = {}
    drug_names = GenericDrugController.new.preformat_regimen
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')
    drug_names.each do |drug_name|
     drug = Drug.find_by_name(drug_name)
      last_physical_count_enc = Pharmacy.find_by_sql(
          "SELECT * from pharmacy_obs WHERE
           drug_id = #{drug.id} AND pharmacy_encounter_type = #{pharmacy_encounter_type.id} AND
           DATE(encounter_date) = (
            SELECT MAX(DATE(encounter_date)) FROM pharmacy_obs
            WHERE drug_id =#{drug.id} AND pharmacy_encounter_type = #{pharmacy_encounter_type.id}
          ) LIMIT 1;"
      ).last

      last_physical_count_date = last_physical_count_enc.encounter_date.to_date rescue nil
      current_stock = Pharmacy.current_stock_after_dispensation(drug.id, last_physical_count_date)
      total_drug_dispensations = Pharmacy.dispensed_drugs_since(drug.id, last_physical_count_date)
      total_days = (Date.today - last_physical_count_date).to_i rescue 0 #Difference in days between two dates.
      total_days = 1 if (total_days == 0) #We are trying to avoid division by zero error
      consumption_rate = (total_drug_dispensations/total_days)
      stock_out_days = (current_stock/consumption_rate).to_i rescue 0 #To avoid division by zero error when consumption_rate is zero
      estimated_stock_out_date = (Date.today + stock_out_days).strftime('%d-%b-%Y')
      estimated_stock_out_date = "Stocked out" if (current_stock <= 0) #We don't want to estimate the stock out date if there is no stock available

      @stock[drug.id] = {}
      @stock[drug.id]["drug_name"] = drug.name
      @stock[drug.id]["current_stock"] = current_stock
      @stock[drug.id]["consumption_rate"] = consumption_rate.to_f.round(1)
      @stock[drug.id]["estimated_stock_out_date"] = estimated_stock_out_date
    end
    @stock = @stock.sort_by{|drug_id, values|values["drug_name"]}
	end

	# Update the session with the location information
	def update    
		# First try by id, then by name
		location = Location.find(params[:location]) rescue nil
		location ||= Location.find_by_name(params[:location]) rescue nil

		valid_location = (generic_locations.include?(location.name)) rescue false

		unless location and valid_location
			flash[:error] = "Invalid workstation location"

			@login_wards = (CoreService.get_global_property_value('facility.login_wards')).split(',') rescue []
			if (CoreService.get_global_property_value('select_login_location').to_s == "true" rescue false)
				render :template => 'sessions/select_location'
			else
				render :action => 'location'
			end
			return    
		end
		self.current_location = location
		if use_user_selected_activities and not location.name.match(/Outpatient/i)
			redirect_to "/user/programs/#{current_user.id}"
		else
			redirect_to '/clinic'
		end
	end

	def destroy
		sign_out(current_user) if !current_user.blank?
		self.current_location = nil
		flash[:notice] = "You have been logged out."
		redirect_back_or_default('/')
	end

	protected
		# Track failed login attempts
		def note_failed_signin
			flash[:error] = "Invalid user name or password"
			logger.warn "Failed login for '#{params[:login]}' from #{request.remote_ip} at #{Time.now.utc}"
		end
end
