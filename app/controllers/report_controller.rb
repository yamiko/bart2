class ReportController < GenericReportController

	def set_appointments
    @logo = CoreService.get_global_property_value('logo').to_s rescue ''
    @current_location_name = Location.current_health_center.name
    @report_name = 'Appointments Report' #find means of making the report name dynamic
		@select_date = params[:user_selected_date].to_date rescue Date.today
    @formatted_appointment_date = @select_date.strftime('%A, %d - %b - %Y')
		@patients = appointments_for_the_day(@select_date)
		render :layout => 'report'
	end

	def appointments_for_the_day(date = Date.today, identifier_type = 'Filing number')
    	concept_id = ConceptName.find_by_name("Appointment date").concept_id

		records = Observation.find(:all,
			:conditions =>["obs.concept_id = ? AND value_datetime >= ? AND value_datetime <=?",
				concept_id, date.strftime('%Y-%m-%d 00:00:00'), date.strftime('%Y-%m-%d 23:59:59')],
			:order => "obs.obs_datetime DESC")
	
		demographics = {}
		(records || []).each do |r|
			patient = PatientService.get_patient(Person.find(r.person_id))
			demographics[r.obs_id] = {	:first_name => patient.first_name,
										:last_name => patient.last_name,
										:gender => patient.sex,
										:birthdate => patient.birth_date,
										:visit_date => r.obs_datetime,
										:patient_id => r.person_id,
										:identifier => patient.filing_number || patient.arv_number }
		end
		return demographics
	end

end
