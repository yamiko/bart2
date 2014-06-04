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
    @visits = {}
    encounter_type = ["PART_FOLLOWUP",'HIV STAGING','HIV RECEPTION',
      'HIV CLINIC REGISTRATION','DISPENSING','HIV CLINIC CONSULTATION',
      'TREATMENT','APPOINTMENT','ART ADHERENCE']

    encounter_type_ids =  EncounterType.find(:all,:conditions => ["name IN(?)",encounter_type]).map(&:id)

    ((7.day.ago.to_date..1.day.ago.to_date).map{ |date| date }).each do |date|
      @visits[date] = {:number_of_patients => 0, :avg_waiting_time => 0,:total_clinic_hrs => 0 }
      @visits[date][:number_of_patients] = Encounter.count(:all,:conditions =>["encounter_type IN(?) 
        AND encounter_datetime BETWEEN ? AND ?",encounter_type_ids,date.strftime('%Y-%m-%d 00:00:00'),
        date.strftime('%Y-%m-%d 23:59:59')])
    end


    (@visits || {}).each do |date, attr|
      rec = Encounter.find(:all,:conditions => ["encounter.encounter_datetime BETWEEN ? AND ? 
        AND (RIGHT(encounter.encounter_datetime,2) <> '01' 
        AND RIGHT(encounter.encounter_datetime,2) <> '01')
        AND encounter.encounter_type IN(?)",date.strftime('%Y-%m-%d 00:00:00'),
        date.strftime('%Y-%m-%d 23:59:59'), encounter_type_ids],
        :group => "encounter.patient_id",:select => "encounter.patient_id, 
        TIMEDIFF( MAX(encounter.encounter_datetime) , MIN(encounter.encounter_datetime) ) difference")

      next if rec.blank?

      time = '00:00:00'
      sum_time = []
      rec.collect do |t| 
        result = ActiveRecord::Base.connection.select_value <<EOF
          SELECT ADDTIME(TIME('#{time}'),TIME('#{t.difference}'));
EOF

        sec = ActiveRecord::Base.connection.select_value <<EOF
          SELECT TIME_TO_SEC(TIME('#{result}'));
EOF

        time = t.difference
        sum_time << [result,sec]
      end
      @visits[date][:avg_waiting_time] = (sum_time.last.last.to_i/rec.length)
      @visits[date][:total_clinic_hrs] = sum_time.last
    end

      
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
