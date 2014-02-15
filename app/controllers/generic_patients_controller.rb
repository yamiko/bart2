class GenericPatientsController < ApplicationController
	before_filter :find_patient, :except => [:void]
  
	def show
    
		current_state = tb_status(@patient).downcase
		@show_period = false
		@show_period = true if current_state.match(/currently in treatment/i)
		session[:mastercard_ids] = []
    session[:datetime] = params[:session] if params[:session]
		session_date = session[:datetime].to_date rescue Date.today
		@patient_bean = PatientService.get_patient(@patient.person)
		@encounters = @patient.encounters.find_by_date(session_date)
		@diabetes_number = DiabetesService.diabetes_number(@patient)
		@prescriptions = @patient.orders.unfinished.prescriptions.all
		@programs = @patient.patient_programs.all
		@alerts = alerts(@patient, session_date) rescue nil
		@restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		@restricted.each do |restriction|    
			@encounters = restriction.filter_encounters(@encounters)
			@prescriptions = restriction.filter_orders(@prescriptions)
			@programs = restriction.filter_programs(@programs)
		end
    @died = 0
    @programs.each do |program|
      @died = 1 if program.patient_states.last.to_s.match(/Patient died/i)
    end
		#@tb_status = PatientService.patient_tb_status(@patient)
		#raise @tb_status.downcase.to_yaml
    @art_start_date = PatientService.patient_art_start_date(@patient)
		@art_start_date = definitive_state_date(@patient, "ON ARV") if @art_start_date.blank?
    @second_line_treatment_start_date = PatientService.date_started_second_line_regimen(@patient)
		@date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

		@location = Location.find(session[:location_id]).name rescue ""
		if @show_period == true
			@tb_registration_date = definitive_state_date(@patient, "TB PROGRAM")
		end
		
		if @location.downcase == "outpatient" || params[:source]== 'opd'
			render :template => 'dashboards/opdtreatment_dashboard', :layout => false
		else
			@task = main_next_task(Location.current_location, @patient, session_date)
			@hiv_status = PatientService.patient_hiv_status(@patient)
			@pre_art_start_date = definitive_state_date(@patient, "HIV PROGRAM")

			@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
			if  !@reason_for_art_eligibility.nil? && @reason_for_art_eligibility.upcase == 'NONE'
				@reason_for_art_eligibility = nil				
			end
			@arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
      @tb_number = PatientService.get_patient_identifier(@patient, 'District TB Number')

#######################
      regimen_category = Concept.find_by_name("Regimen Category")
      @current_regimen = Observation.find_by_sql("SELECT * FROM obs o INNER JOIN encounter enc ON
      o.encounter_id= enc.encounter_id AND
      enc.encounter_type= (SELECT encounter_type_id FROM encounter_type WHERE
      name='DISPENSING') AND o.concept_id=#{regimen_category.id} AND enc.patient_id=#{@patient.id}
      AND enc.voided = 0
      order by enc.date_created DESC LIMIT 1").first.answer_string.squish rescue nil

      identifier_types = ["Legacy Pediatric id","National id","Legacy National id"]
      identifiers = PatientIdentifierType.find(:all, :conditions=>["name IN (?)",
        identifier_types]).collect{| type |type.id }

      patient_identifiers = PatientIdentifier.find(:all, :conditions=>["patient_id=? AND
       identifier_type IN (?)", @patient.id, identifiers]).collect{| i | i.identifier }
    
      if show_lab_results

        cd4_results = Lab.latest_result_by_test_type(@patient, 'CD4', patient_identifiers) rescue nil
        @cd4_results = cd4_results
        @cd4_latest_date = cd4_results[0].split('::')[0].to_date rescue nil
        @cd4_latest_result = cd4_results[1]["TestValue"] rescue nil
        @cd4_modifier = cd4_results[1]["Range"] rescue nil
        
        vl_results = Lab.latest_result_by_test_type(@patient, 'HIV_viral_load', patient_identifiers) rescue nil
        @vl_results = vl_results
        @vl_latest_date = vl_results[0].split('::')[0].to_date rescue nil
        @vl_latest_result = vl_results[1]["TestValue"] rescue nil
        @vl_modifier = vl_results[1]["Range"] rescue nil
      end

        @current_hiv_program_status = Patient.find_by_sql("
											SELECT patient_id, current_state_for_program(patient_id, 1, '#{session_date}') AS state, c.name as status
											FROM patient p INNER JOIN program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(patient_id, 1, '#{session_date}')
											INNER JOIN concept_name c ON c.concept_id = pw.concept_id where p.patient_id = '#{@patient.patient_id}'").first.status rescue "Unknown"
       ####################
      render :template => 'patients/index', :layout => false
		end
	end

  def opdcard
    @patient = Patient.find(params[:id])
    render :layout => 'menu' 
  end

  def opdshow
    session_date = session[:datetime].to_date rescue Date.today
    encounter_types = EncounterType.find(:all,:conditions =>["name IN (?)",
        ['REGISTRATION','OUTPATIENT DIAGNOSIS','REFER PATIENT OUT?','OUTPATIENT RECEPTION','DISPENSING']]).map{|e|e.id}
    @encounters = Encounter.find(:all,:select => "encounter_id , name encounter_type_name, count(*) c",
      :joins => "INNER JOIN encounter_type ON encounter_type_id = encounter_type",
      :conditions =>["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
        params[:id],encounter_types,session_date],
      :group => 'encounter_type').collect do |rec| 
			if current_user.user_roles.map{|r|r.role}.join(',').match(/Registration|Clerk/i)
				next unless rec.observations[0].to_s.match(/Workstation location:   Outpatient/i)
			end
			[ rec.encounter_id , rec.encounter_type_name , rec.c ]
		end
    
    render :template => 'dashboards/opdoverview_tab', :layout => false
  end

  def opdtreatment
    render :template => 'dashboards/opdtreatment_dashboard', :layout => false
  end

  def opdtreatment_tab
    @activities = [
      ["Visit card","/patients/opdcard/#{params[:id]}"],
      ["National ID (Print)","/patients/dashboard_print_national_id?id=#{params[:id]}&redirect=patients/opdtreatment"],
      ["Referrals", "/encounters/referral/#{params[:id]}"],
      ["Give drugs", "/encounters/opddrug_dispensing/#{params[:id]}"],
      ["Vitals", "/report/data_cleaning"],
      ["Outpatient diagnosis","/encounters/new?id=show&patient_id=#{params[:id]}&encounter_type=outpatient_diagnosis"]
    ]
    render :template => 'dashboards/opdtreatment_tab', :layout => false
  end

  def treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date])

    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
    end

    @encounters = @patient.encounters.find_by_date(session_date)

    @transfer_out_site = nil

    @encounters.each do |enc|
      enc.observations.map do |obs|
				@transfer_out_site = obs.to_s if obs.to_s.include?('Transfer out to')
			end
    end
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'dashboards/dispension_tab', :layout => false
  end

  def history_treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    @patient = Patient.find(params[:patient_id])
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ?",type.id,@patient.id])

    @historical = @patient.orders.historical.prescriptions.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @historical = restriction.filter_orders(@historical)
    end

    render :template => 'dashboards/treatment_tab', :layout => false
  end

  def guardians
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
    	render :template => 'dashboards/relationships_tab', :layout => false
  	end
  end

  def relationships
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
      next_form_to = next_task(@patient)
      redirect_to next_form_to and return if next_form_to.match(/Reception/i)
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
			@patient_arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
			@patient_bean = PatientService.get_patient(@patient.person)
    	render :template => 'dashboards/relationships', :layout => 'dashboard' 
  	end
  end

  def problems
    render :template => 'dashboards/problems', :layout => 'dashboard' 
  end

  def personal
    @links = []
    patient = Patient.find(params[:id])

    @links << ["Demographics (Print)","/patients/print_demographics/#{patient.id}"]
    @links << ["Visit Summary (Print)","/patients/dashboard_print_visit/#{patient.id}"]
    @links << ["National ID (Print)","/patients/dashboard_print_national_id/#{patient.id}"]
    @links << ["Demographics (Edit)","/people/demographics/#{patient.id}"]
		@links << ["Lab Results","/encounters/lab_results_print/#{patient.id}"]

    if use_filing_number and not PatientService.get_patient_identifier(patient, 'Filing Number').blank?
      @links << ["Filing Number (Print)","/patients/print_filing_number/#{patient.id}"]
    end 

    if use_filing_number and PatientService.get_patient_identifier(patient, 'Filing Number').blank?
      @links << ["Filing Number (Create)","/patients/set_filing_number/#{patient.id}"]
    end 

    if use_user_selected_activities
      @links << ["Change User Activities","/user/activities/#{current_user.id}?patient_id=#{patient.id}"]
    end
      
    if show_lab_results
      @links << ["Lab trail", "/lab/results/#{patient.id}"]
    end

    @links << ["Recent Lab Orders Label","/patients/recent_lab_orders?patient_id=#{patient.id}"]
    @links << ["Transfer out label (Print)","/patients/print_transfer_out_label/#{patient.id}"]
		@links << ["TB Transfer out label (Print)","/patients/print_transfer_out_tb/#{patient.id}"]

    render :template => 'dashboards/personal_tab', :layout => false
  end

  def history
    render :template => 'dashboards/history', :layout => 'dashboard' 
  end

  def programs
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    flash.now[:error] = params[:error] unless params[:error].blank?

    unless flash[:error].nil?
      redirect_to "/patients/programs_dashboard/#{@patient.id}?error=#{params[:error]}" and return
    else
      render :template => 'dashboards/programs_tab', :layout => false
    end
  end

  def graph
    @currentWeight = params[:currentWeight]
    render :template => "graphs/#{params[:data]}", :layout => false 
  end

  def void 
    @encounter = Encounter.find(params[:encounter_id])
    @encounter.void
    show and return
  end
  
  def print_registration
    print_and_redirect("/patients/national_id_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end
  
  def dashboard_print_national_id
    unless params[:redirect].blank?
      redirect = "/#{params[:redirect]}/#{params[:id]}"
    else
      redirect = "/patients/show/#{params[:id]}"
    end
    print_and_redirect("/patients/national_id_label?patient_id=#{params[:id]}", redirect)  
  end
  
  def dashboard_print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")
  end
  
  def print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end

  def print_mastercard_record
    print_and_redirect("/patients/mastercard_record_label/?patient_id=#{@patient.id}&date=#{params[:date]}", "/patients/visit?date=#{params[:date]}&patient_id=#{params[:patient_id]}")
  end

  def print_demographics
    print_and_redirect("/patients/patient_demographics_label/#{@patient.id}", "/patients/show/#{params[:id]}")
  end
 
  def print_filing_number
    print_and_redirect("/patients/filing_number_label/#{params[:id]}", "/patients/show/#{params[:id]}")  
  end
   
  def print_transfer_out_label
    print_and_redirect("/patients/transfer_out_label?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")  
  end

  def print_transfer_out_tb
    print_and_redirect("/patients/transfer_out_label_tb?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")
  end
   
  def patient_demographics_label
    print_string = demographics_label(params[:id])
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
  
  def national_id_label
    print_string = PatientService.patient_national_id_label(@patient) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_lab_orders
    patient_id = params[:patient_id]
    patient = Patient.find(patient_id)

    print_and_redirect("/patients/lab_orders_label/?patient_id=#{patient.id}", next_task(patient))
  end

  def lab_orders_label
    patient = Patient.find(params[:patient_id])
    label_commands = patient_lab_orders_label(patient.id)

    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbs", :disposition => "inline")
  end

  def filing_number_label
    patient = Patient.find(params[:id])
    label_commands = patient_filing_number_label(patient)
    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def filing_number_and_national_id
    patient = Patient.find(params[:patient_id])
    label_commands = PatientService.patient_national_id_label(patient) + patient_filing_number_label(patient)

    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def visit_label
		session_date = session[:datetime].to_date rescue Date.today
    print_string = patient_visit_label(@patient, session_date) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def specific_patient_visit_date_label
		session_date = params[:session_date].to_date rescue Date.today
    print_string = patient_visit_label(@patient, session_date) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard_record_label
    print_string = patient_visit_label(@patient, params[:date].to_date)
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def transfer_out_label
    print_string = patient_transfer_out_label(params[:patient_id])
    send_data(print_string,
      :type=>"application/label; charset=utf-8", 
      :stream=> false, 
      :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", 
      :disposition => "inline")
  end

  def transfer_out_label_tb
    print_string = patient_tb_transfer_out_label(params[:patient_id])
    send_data(print_string,
      :type=>"application/label; charset=utf-8",
      :stream=> false,
      :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl",
      :disposition => "inline")
  end

  def mastercard_menu
    render :layout => "menu"
    @patient_id = params[:patient_id]
  end

  def mastercard
    @type = params[:type]
    
    if session[:from_report].to_s == "true"
			@from_report = true
			session[:from_report] = false
    end
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    
    if params[:show_mastercard_counter].to_s == "true" && !params[:current].blank?
			@show_mastercard_counter = true
			session[:mastercard_counter] = params[:current].to_i - 1
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      
      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      end
      
    elsif params[:patient_id].blank?
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]] 
           
    elsif session[:mastercard_ids].length.to_i != 0
      @patient_id = params[:patient_id]
      
    else
      @patient_id = params[:patient_id]
      
    end

    unless params.include?("source")
      @source = params[:source] rescue nil
    else
      @source = nil
    end

    render :layout => "menu"
    
  end

  def mastercard_printable
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false

    if params[:patient_id].blank?

      @show_mastercard_counter = true

      if !params[:current].blank?
        session[:mastercard_counter] = params[:current].to_i - 1
      end
      
      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      else

      end
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
      @visits = visits(Patient.find(@patient_id))
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id)
      # elsif session[:mastercard_ids].length.to_i != 0
      #  @patient_id = params[:patient_id]
      #  @data_demo = mastercard_demographics(Patient.find(@patient_id))
      #  @visits = visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id)
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
			#raise @data_demo.eptb.to_yaml
      @visits = visits(Patient.find(@patient_id))
    end

    @visits.keys.each do|day|
			@age_in_months_for_days[day] = PatientService.age_in_months(@patient.person, day.to_date)
    end rescue nil

    render :layout => false
  end

  def visit
    @patient_id = params[:patient_id] 
    @date = params[:date].to_date
    @patient = Patient.find(@patient_id)
    @patient_bean = PatientService.get_patient(@patient.person)
    @patient_gaurdians = @patient.person.relationships.map{|r| PatientService.name(Person.find(r.person_b)) }.join(' : ')
    @visits = visits(@patient,@date)
    render :layout => "menu"
  end

  def next_available_arv_number
    next_available_arv_number = PatientIdentifier.next_available_arv_number
    render :text => next_available_arv_number.gsub(PatientIdentifier.site_prefix,'').strip rescue nil
  end
  
  def assigned_arv_number
    assigned_arv_number = PatientIdentifier.find(:all,:conditions => ["voided = 0 AND identifier_type = ?",
        PatientIdentifierType.find_by_name("ARV Number").id]).collect{|i| i.identifier.gsub("#{PatientIdentifier.site_prefix}-ARV-",'').strip.to_i} rescue nil
    render :text => assigned_arv_number.sort.to_json rescue nil 
  end

  def mastercard_modify
    if request.method == :get
      @patient_id = params[:id]
      @patient = Patient.find(params[:id])
      @edit_page = edit_mastercard_attribute(params[:field].to_s)

      if @edit_page == "guardian"
        @guardian = {}
        @patient.person.relationships.map{|r| @guardian[art_guardian(@patient)] = Person.find(r.person_b).id.to_s;'' }
        if  @guardian == {}
          redirect_to :controller => "relationships" , :action => "search",:patient_id => @patient_id
        end
      end
    else
      @patient_id = params[:patient_id]
      save_mastercard_attribute(params)
      if params[:source].to_s == "opd"
        redirect_to "/patients/opdcard/#{@patient_id}" and return
      elsif params[:from_demo] == "true"
        redirect_to :controller => "people" ,
					:action => "demographics",:id => @patient_id and return
      else
        redirect_to :action => "mastercard",:patient_id => @patient_id and return
      end
    end
  end

  def summary
    @encounter_type = params[:skipped]
    @patient_id = params[:patient_id]
    render :layout => "menu"
  end

  def set_filing_number
    patient = Patient.find(params[:id])
		PatientService.set_patient_filing_number(patient)

    archived_patient = PatientService.patient_to_be_archived(patient)
    message = PatientService.patient_printing_message(patient,archived_patient,true)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/patients/show/#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/patients/show/#{patient.id}")
    end
  end

  def set_new_filing_number
    patient = Patient.find(params[:id])
    set_new_patient_filing_number(patient)
    archived_patient = PatientService.patient_to_be_archived(patient)
    message = PatientService.patient_printing_message(patient, archived_patient)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/people/confirm?found_person_id=#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/people/confirm?found_person_id=#{patient.id}")
    end
  end

  def export_to_csv
    ( Patient.find(:all,:limit => 10) || [] ).each do | patient |
      patient_bean = PatientService.get_patient(patient.person)
      csv_string = FasterCSV.generate do |csv|
        # header row
        csv << ["ARV number", "National ID"]
        csv << [PatientService.get_patient_identifier(patient, 'ARV Number'), PatientService.get_national_id(patient)]
        csv << ["Name", "Age","Sex","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]
        transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
        transfer_in.blank? == true ? transfer_in = 'NO' : transfer_in = 'YES'
        csv << [patient.person.name,patient.person.age, PatientService.sex(patient.person),PatientService.get_patient_attribute_value(patient, "initial_weight"),PatientService.get_patient_attribute_value(patient, "initial_height"),PatientService.get_patient_attribute_value(patient, "initial_bmi"),transfer_in]
        csv << ["Location", "Land-mark","Occupation","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]

=begin
        # data rows
        @users.each do |user|
          csv << [user.id, user.username, user.salt]
        end
=end
      end
      # send it to the browsbah
      send_data csv_string.gsub(' ','_'),
        :type => 'text/csv; charset=iso-8859-1; header=present',
        :disposition => "attachment:wq
              ; filename=patient-#{patient.id}.csv"
    end
  end

  def print_mastercard
    if @patient
      t1 = Thread.new{
        Kernel.system "htmldoc --webpage --landscape --linkstyle plain --left 1cm --right 1cm --top 1cm --bottom 1cm -f /tmp/output-" +
          current_user.user_id.to_s + ".pdf http://" + request.env["HTTP_HOST"] + "\"/patients/mastercard_printable?patient_id=" +
          @patient.id.to_s + "\"\n"
      }

      t2 = Thread.new{
        sleep(5)
        Kernel.system "lpr /tmp/output-" + current_user.user_id.to_s + ".pdf\n"
      }

      t3 = Thread.new{
        sleep(10)
        Kernel.system "rm /tmp/output-" + current_user.user_id.to_s + ".pdf\n"
      }

    end
    
    redirect_to request.request_uri.to_s.gsub('print_mastercard', 'mastercard') and return
  end
  
  def demographics
	  @patient_bean = PatientService.get_patient(@patient.person)
    render :layout => false
  end
   
  def index
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date)
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")
    @task = main_next_task(Location.current_location,@patient,session_date)
    
    @hiv_status = PatientService.patient_hiv_status(@patient)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'patients/index', :layout => false
  end

  def overview
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
  #raise @programs.first.patient_states.last.to_s
    @alerts = alerts(@patient, session_date) rescue nil
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end
   # raise @programs.first.patient_states.to_yaml
=begin
   @program_state =  []
   @programs.each do | prog |
    
    patient_states = PatientState.find(:all,
				:joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
				:conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND start_date <= ? AND p.patient_id =?",
					prog.program_id, session_date, @patient.id],:order => "patient_state_id ASC")
     @program_state << [prog.to_s,  patient_states.last.to_s, prog.program_id, prog.date_enrolled]
    end
=end
    render :template => 'dashboards/overview_tab', :layout => false
  end

  def visit_history
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
		start_date = session_date.strftime('%Y-%m-%d 00:00:00')
		end_date = session_date.strftime('%Y-%m-%d 23:59:59')
    @encounters = Encounter.find(:all, 	:conditions => [" patient_id = ? AND encounter_datetime >= ? AND encounter_datetime <= ?", @patient.id, start_date, end_date]) 
    
    @creator_name = {}
    @encounters.each do |encounter|
    	id = encounter.creator
			user_name = User.find(id).person.names.first
			@creator_name[id] = '(' + user_name.given_name.first + '. ' + user_name.family_name + ')'
    end
    
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date) rescue nil
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    render :template => 'dashboards/visit_history_tab', :layout => false
  end

	def get_previous_encounters(patient_id)
		session_date = (session[:datetime].to_date rescue Date.today.to_date) - 1.days
		session_date = session_date.to_s + ' 23:59:59'
    previous_encounters = Encounter.find(:all,
			:conditions => ["encounter.voided = ? and patient_id = ? and encounter.encounter_datetime <= ?", 0, patient_id, session_date],
			:include => [:observations],:order => "encounter.encounter_datetime DESC"
		)
			
    return previous_encounters
  end

  def past_visits_summary
    @previous_visits  = get_previous_encounters(params[:patient_id])

    @encounter_dates = @previous_visits.map{|encounter| encounter.encounter_datetime.to_date}.uniq.first(6) rescue []

    @past_encounter_dates = @encounter_dates

    render :template => 'dashboards/past_visits_summary_tab', :layout => false
  end

  def patient_dashboard
    session_date = session[:datetime].to_date rescue Date.today
    @patient_bean = PatientService.get_patient(Person.find(params[:patient_id] || params[:found_person_id]))
    patient = Patient.find(params[:patient_id] || params[:found_person_id])
    @task = main_next_task(Location.current_location, patient, session_date)

    @show_history = false
    @show_history = current_user_roles.include?("Clinician") unless @show_history
    @show_history = current_user_roles.include?("Nurse") unless @show_history
    @show_history = current_user_roles.include?("Doctor") unless @show_history
    @show_history = current_user_roles.include?("Program Manager") unless @show_history
    @show_history = current_user_roles.include?("System Developer") unless @show_history

    @encounters = {}
    @encounter_dates = []

    if @show_history
      last_visit_date = patient.encounters.last.encounter_datetime.to_date rescue Date.today
      latest_encounters = Encounter.find(:all,
        :order => "encounter_datetime ASC,date_created ASC",
        :conditions => ["patient_id = ? AND
        encounter_datetime >= ? AND encounter_datetime <= ?",patient.patient_id,
					last_visit_date.strftime('%Y-%m-%d 00:00:00'),
					last_visit_date.strftime('%Y-%m-%d 23:59:59')])

      (latest_encounters || []).each do |encounter|
        next if encounter.name.match(/TREATMENT/i)
        @encounters[encounter.name.upcase] = {:data => nil,
          :time => encounter.encounter_datetime.strftime('%H:%M:%S')}
        @encounters[encounter.name.upcase][:data] = encounter.observations.collect{|obs|
          next if obs.to_s.match(/Workstation/i)
          obs.to_s
        }.compact
      end

      @encounters = @encounters.sort_by { |name, values| values[:time] }

      @encounter_dates = patient.encounters.collect{|e|e.encounter_datetime.to_date}.uniq
      @encounter_dates = (@encounter_dates || []).sort{|a,b|b <=> a}
    end
    render :layout => "menu"
  end

  def treatment_dashboard
		@dispense = CoreService.get_global_property_value('use_drug_barcodes_only')
	  @patient_bean = PatientService.get_patient(@patient.person)
    @amount_needed = 0
    @amounts_required = 0

    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date]).each{|order|
      
      @amount_needed = @amount_needed + (order.drug_order.amount_needed.to_i rescue 0)

      @amounts_required = @amounts_required + (order.drug_order.total_required rescue 0)

    }

    @dispensed_order_id = params[:dispensed_order_id]
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'dashboards/treatment_dashboard', :layout => false
  end

  def guardians_dashboard
	  @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'dashboards/relationships_dashboard', :layout => false
  end

  def programs_dashboard
	  @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
    render :template => 'dashboards/programs_dashboard', :layout => false
  end

  def general_mastercard
    @type = nil
    
    case params[:type]
    when "1"
      @type = "yellow"
    when "2"
      @type = "green"
    when "3"
      @type = "pink"
    when "4"
      @type = "blue"
    end

    @mastercard = mastercard_demographics(@patient)
    @patient_art_start_date = PatientService.patient_art_start_date(@patient.id)
    @visits = visits(@patient)   # (@patient, (session[:datetime].to_date rescue Date.today))
    
    @age_in_months_for_days = {}
    @visits.keys.each do|day|
			@age_in_months_for_days[day] = PatientService.age_in_months(@patient.person, day.to_date)
    end
    
    @patient_age_at_initiation = PatientService.patient_age_at_initiation(@patient,
			PatientService.patient_art_start_date(@patient.id))
                                              
    @patient_bean = PatientService.get_patient(@patient.person)
		@guardian_phone_number = PatientService.get_attribute(Person.find(@patient.person.relationships.first.person_b), 'Cell phone number') rescue nil
		@patient_phone_number = PatientService.get_attribute(@patient.person, 'Cell phone number')
    #render :layout => false
  end

  def patient_details
    render :layout => false
  end

  def status_details
    render :layout => false
  end

  def mastercard_details
    render :layout => false
  end

  def mastercard_header
    render :layout => false
  end

  def number_of_booked_patients
    date = params[:date].to_date
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id

    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')

    appointments = Observation.find_by_sql("SELECT count(*) AS count FROM obs 
      INNER JOIN encounter e USING(encounter_id) WHERE concept_id = #{concept_id} 
      AND encounter_type = #{encounter_type.id} AND value_datetime >= '#{start_date}' 
      AND value_datetime <= '#{end_date}' AND obs.voided = 0 GROUP BY value_datetime")
    count = appointments.first.count unless appointments.blank?
    count = '0' if count.blank?

    render :text => (count.to_i >= 0 ? {params[:date] => count}.to_json : 0)
  end

  def recent_lab_orders_print
    patient = Patient.find(params[:id])
    lab_orders_label = params[:lab_tests].split(":")

    label_commands = recent_lab_orders_label(lab_orders_label, patient)
    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbs", :disposition => "inline")
  end

  def print_recent_lab_orders_label
    #patient = Patient.find(params[:id])
    lab_orders_label = params[:lab_tests].join(":")

    #raise lab_orders_label.to_s
    #label_commands = patient.recent_lab_orders_label(lab_orders_label)
    #send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")

    print_and_redirect("/patients/recent_lab_orders_print/#{params[:id]}?lab_tests=#{lab_orders_label}" , "/patients/show/#{params[:id]}")
  end

  def recent_lab_orders
    patient = Patient.find(params[:patient_id])
    @lab_order_labels = get_recent_lab_orders_label(patient.id)
    @patient_id = params[:patient_id]
  end

  def next_task_description
    @task = Task.find(params[:task_id]) rescue Task.new
    render :template => 'dashboards/next_task_description', :layout => false
  end

  def tb_treatment_card # to look at later - To test that is
  @patient = Patient.find(params[:patient_id])
	@variables = Hash.new()
	@patient_bean = PatientService.get_patient(@patient.person)
	@variables["hiv"] =  PatientService.patient_hiv_status(@patient.person) rescue nil
	tbStart = Encounter.find(:last, :conditions => ["encounter_type = ? AND patient_id =?", EncounterType.find_by_name("tb registration").id, @patient.person]) rescue nil
if (tbStart != nil)	
	duration = Time.now.to_date - tbStart.encounter_datetime.to_date
	@variables["patientId"] = PatientIdentifier.find(:last, :conditions => ["patient_id = ? and identifier_type = ?",@patient_bean.patient_id, PatientIdentifierType.find_by_name("district tb number").id]).identifier rescue " "
  	@variables["tbStart"] = tbStart.encounter_datetime.to_time.strftime('%A, %d %B %Y') rescue nil
	@variables["arvStart"] = PatientService.patient_art_start_date(@patient.person).to_date.strftime(' %d- %b- %Y') rescue nil
	@variables["regimen"] = Concept.find(:first, :conditions => ["concept_id = ?" ,PatientProgram.find(:all, :conditions => ["patient_id =? AND program_id = ?", @patient.person, Program.find_by_name("tb program").id]).last.current_regimen]).shortname rescue nil

	status = @variables["arvStart"].to_date - tbStart.encounter_datetime.to_date rescue nil

	if status == nil
			@variables["status"] = "C"
	elsif sputum !=nil and sputum > 0
			@variables["status"] = "A"
	else
			@variables["status"] = "B"
	end

	
			@observations = Observation.find(:all, :conditions => ["encounter_id = ?", tbStart.encounter_id]) rescue nil

			x = 0
			while x < @observations.length
				if @observations[x].concept.fullname == "Tuberculosis classification"
					@variables["tbType"] = @observations.fetch(x).name

				elsif @observations[x].concept.fullname == "TB patient category"
					@variables["patientType"] = @observations.fetch(x).answer_string
				elsif @observations[x].concept.fullname == "Directly observed treatment option"
					@variables["dotOption"] = @observations.fetch(x).answer_string
				end
				x +=1
			end
		end
	

		render :layout => 'menu'
  end

  def tb_treatment_card_page
		#this method calls the page that displays a patients treatment records
		@patient_bean = PatientService.get_patient(@patient.person)
		@previous_visits  = get_previous_tb_visits(@patient.person)
		smears = PatientService.sputum_results_by_date(@patient.person) rescue nil
		tbStart = Encounter.find(:last, :conditions => ["encounter_type = ? AND patient_id =?", EncounterType.find_by_name("TB Registration").id, @patient.person]) rescue nil
		@variables = Hash.new("")
	  	
		obs = Observation.find(:first, :conditions => ["person_id = ? AND concept_id = ? AND obs_datetime = ?",@patient.person,ConceptName.find_by_name("Weight").concept_id,tbStart.encounter_datetime]) rescue nil

		#retrieve hiv status as required
		@variables["hiv1"]=@variables["hiv2"]=@variables["hiv3"]=@variables["hiv4"] = " "
		if (obs != nil)
			if @variables["status"] == "A"
				@variables["hiv1"]=@variables["hiv2"]=@variables["hiv3"]=@variables["hiv4"] = "Past Postive"
			elsif(obs.obs_datetime.to_date <= Date.today)
				@variables["hiv1"] = PatientService.patient_hiv_status_by_date(@patient.person, obs.obs_datetime.to_date)
			elsif((obs.obs_datetime.to_date + 60) <= duration)
				@variables["hiv2"] = PatientService.patient_hiv_status_by_date(@patient.person, obs.obs_datetime.to_date)
			elsif((obs.obs_datetime.to_date + 150) <= duration)
				@variables["hiv3"] = PatientService.patient_hiv_status_by_date(@patient.person, obs.obs_datetime.to_date)
			elsif((obs.obs_datetime.to_date + 180) <= duration)
				@variables["hiv4"] = PatientService.patient_hiv_status_by_date(@patient.person, obs.obs_datetime.to_date)
			end
		end

if (obs != nil)	
	@variables["startWeight"] = obs.value_numeric rescue nil
	@variables["startWeightdate"] = obs.obs_datetime.strftime('%d/%m/%Y') rescue nil
	temp = PatientService.sputum_by_date(smears, obs.obs_datetime.to_date) rescue nil
	@variables["smear1AAccession"] = temp["acc1"] +"/"+temp["acc2"] rescue nil
	@variables["smear1Aresult"] = temp["result1"] +"/"+ temp["result2"] rescue nil
end

	obs = Observation.find(:first, :conditions => ["person_id = ? AND concept_id = ? AND obs_datetime > ?",@patient.person,ConceptName.find_by_name("Weight").concept_id, tbStart.encounter_datetime]) rescue nil
	@variables["weight2"] = obs.value_numeric rescue nil
	@variables["weight2date"] = obs.obs_datetime.strftime('%d/%m/%Y') rescue nil
	temp1 = PatientService.sputum_by_date(smears, obs.obs_datetime.to_date) rescue nil
	if(!temp1.nil?)
		@variables["smear2AAccession"] = temp1["acc1"] +"/" + temp1["acc2"] rescue nil
		@variables["smear2Aresult"] = temp1["result1"] +"/"+ temp1["result2"] rescue nil

		end

	obs = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",@patient.person,ConceptName.find_by_name("Weight").concept_id, tbStart.encounter_datetime.to_date + 145,tbStart.encounter_datetime.to_date + 160 ]) rescue nil
	@variables["weight3"].obs.value_numeric rescue nil
	@variables["weight3date"] = obs.obs_datetime.strftime('%d/%m/%Y') rescue nil
	temp3 = PatientService.sputum_by_date(smears, obs.obs_datetime.to_date) rescue nil
	if (temp3 != nil)
		@variables["smear3AAccesion"] = temp3["acc1"] + "/" + temp3["acc2"] rescue nil
		@variables["smear3Aresult"] = temp3["result1"] + "/" + temp3["result2"] rescue nil


		end

		obs = Observation.find(:first, :conditions => ["person_id = ? AND concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",@patient.person,ConceptName.find_by_name("Weight").concept_id, tbStart.encounter_datetime.to_date + 175,tbStart.encounter_datetime.to_date + 245 ]) rescue nil


	@variables["weight4"] = obs.value_numeric rescue nil
	@variables["weight4date"] = obs.obs_datetime.strftime('%d/%m/%Y') rescue nil
	temp4 = PatientService.sputum_by_date(smears, obs.obs_datetime.to_date) rescue nil
	if (temp4 != nil)
		@variables["smear4AAccesion"] = temp4["acc1"] + "/" + temp4["acc2"] rescue nil
		@variables["smear4Aresult"] = temp4["result1"] + "/" + temp4["result2"] rescue nil
	end

	  	
	render:layout => 'menu'
  end
  
  def get_previous_tb_visits(patient_id)
  
  	start = Encounter.find(:last, :conditions => ["encounter_type = ? AND patient_id =?", EncounterType.find_by_name("tb registration").id, @patient.person]).encounter_datetime rescue nil

		type = EncounterType.find_by_name("TB Adherence").id rescue nil
		results = Array.new()
		adherences = Encounter.find(:all,:conditions => ["patient_id = ? and encounter_type = ? and encounter_datetime >= ?",patient_id,type,start])
		start = adherences[0].date rescue nil
		adherences.each do |work|
			if ((work.date.to_date <= (start.to_date + 10 )) and (work.date.to_date >= (start.to_date - 10 )) and (work.observations[2] != nil))
				results << work
				start = start.to_date + 30

			end
		end
  
    return results
  end


  def alerts(patient, session_date = Date.today) 
    # next appt
    # adherence
    # drug auto-expiry
    # cd4 due
		patient_bean = PatientService.get_patient(patient.person)
    alerts = []

    type = EncounterType.find_by_name("APPOINTMENT")
    
    @show_change_app_date = Observation.find(:first,                          
			:order => "encounter_datetime DESC,encounter.date_created DESC",
			:joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
			:conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
    AND encounter_datetime >= ? AND encounter_datetime <= ?",
				ConceptName.find_by_name('Appointment date').concept_id,
				type.id, patient.id,session_date.strftime("%Y-%m-%d 00:00:00"),
				session_date.strftime("%Y-%m-%d 23:59:59")]) != nil

    next_appt = Observation.find(:first,:order => "encounter_datetime DESC,encounter.date_created DESC",
			:joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
			:conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
               AND obs_datetime <= ?",ConceptName.find_by_name('Appointment date').concept_id,
				type.id,patient.id,session_date.strftime("%Y-%m-%d 23:59:59")
			]).value_datetime.strftime("%a %d %B %Y") rescue nil

    #raise next_appt.to_yaml
    alerts << ('Next appointment: ' + next_appt) unless next_appt.blank?

    encounter_dates = Encounter.find_by_sql("SELECT * FROM encounter WHERE patient_id = #{patient.id} AND encounter_type IN (" +
        ("SELECT encounter_type_id FROM encounter_type WHERE name IN ('VITALS', 'TREATMENT', " +
          "'HIV RECEPTION', 'HIV STAGING', 'HIV CLINIC CONSULTATION', 'DISPENSING')") + ")").collect{|e|
      e.encounter_datetime.strftime("%Y-%m-%d")
    }.uniq

    missed_appt = patient.encounters.find_last_by_encounter_type(type.id, 
      :conditions => ["NOT (DATE_FORMAT(encounter_datetime, '%Y-%m-%d') IN (?)) AND encounter_datetime < NOW()",
        encounter_dates], :order => "encounter_datetime").observations.last.to_s rescue nil
    alerts << ('Missed ' + missed_appt).capitalize unless missed_appt.blank?

    @adherence_level = ConceptName.find_by_name('What was the patients adherence for this drug order').concept_id
    type = EncounterType.find_by_name("ART ADHERENCE")

    observations = Observation.find(:all,:joins =>"INNER JOIN encounter e USING(encounter_id)",
      :conditions =>["concept_id = ? AND encounter_type = ? AND patient_id = ? AND 
      encounter_datetime >= ? AND encounter_datetime <= ?",@adherence_level,type,
				patient.id,session_date.strftime("%Y-%m-%d 00:00:00"),session_date.strftime("%Y-%m-%d 23:59:59")],
      :order => "obs_datetime DESC")

    (observations || []).map do |adh|
      adherence = adh.value_numeric ||= adh.value_text
      if (adherence.to_f >= 95 || adherence.to_f <= 105)
        drug_name = adh.order.drug_order.drug.concept.shortname rescue adh.order.drug_order.drug.name
        alerts << "Adherence: #{drug_name} (#{adh.value_numeric}%)"
      end
    end 

    type = EncounterType.find_by_name("DISPENSING")
    patient.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.each do | obs |
      next if obs.order.blank?
      next if obs.order.auto_expire_date.blank?
      alerts << "Drugs runout date: #{obs.order.drug_order.drug.name} #{obs.order.auto_expire_date.to_date.strftime('%d-%b-%Y')}"
    end rescue []

    # BMI alerts
    if patient_bean.age >= 15
      bmi_alert = current_bmi_alert(PatientService.get_patient_attribute_value(patient, "current_weight"), PatientService.get_patient_attribute_value(patient, "current_height"))
      alerts << bmi_alert if bmi_alert
    end
    
    program_id = Program.find_by_name("HIV PROGRAM").id
    location_id = Location.current_health_center.location_id

    patient_hiv_program = PatientProgram.find(:all,:conditions =>["voided = 0 AND patient_id = ? AND program_id = ? AND location_id = ?", patient.id , program_id, location_id])
		on_art = ''
    hiv_status = PatientService.patient_hiv_status(patient)
    
    alerts << "HIV Status : #{hiv_status} more than 3 months" if ("#{hiv_status.strip}" == 'Negative' && PatientService.months_since_last_hiv_test(patient.id) > 3)
    #alerts << "Patient not on ART" if (("#{hiv_status.strip}" == 'Positive') && !patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) ||
			#((patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) && (ProgramWorkflowState.find_state(patient_hiv_program.last.patient_states.last.state).concept.fullname == "Pre-ART (Continue)"))
		if  ( !patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) ||
			((patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) && (ProgramWorkflowState.find_state(patient_hiv_program.last.patient_states.last.state).concept.fullname == "Pre-ART (Continue)"))
			if "#{hiv_status.strip}" == 'Positive'
				#alerts << "Patient not on ART"
				on_art = "not"
			end
		else
			alerts << "Patient on ART in Local Program"
		end
		if on_art == "not"
			state = Concept.find(Observation.find(:first, 
					:order => "obs_datetime DESC,date_created DESC",
					:conditions => ["person_id = ? AND concept_id = ? AND value_coded IS NOT NULL",
						patient.id, ConceptName.find_by_name("on art").concept_id]).value_coded).fullname rescue ""
				if state.upcase == "YES"
					alerts << "Patient on ART Not in Local Program"
				else
					alerts << "Patient not on ART"
				end
		end
    alerts << "HIV Status : #{hiv_status}" if "#{hiv_status.strip}" == 'Unknown'
    alerts << "Lab: Expecting submission of sputum" unless PatientService.sputum_orders_without_submission(patient.id).empty?
    alerts << "Lab: Waiting for sputum results" if PatientService.recent_sputum_results(patient.id).empty? && !PatientService.recent_sputum_submissions(patient.id).empty?
    alerts << "Lab: Results not given to patient" if !PatientService.recent_sputum_results(patient.id).empty? && given_sputum_results(patient.id).to_s != "Yes"
    alerts << "Patient go for CD4 count testing" if cd4_count_datetime(patient) == true
    alerts << "Lab: Patient must order sputum test" if patient_need_sputum_test?(patient.id)
    alerts << "Refer to ART wing" if show_alert_refer_to_ART_wing(patient)

    alerts
  end

  def cd4_count_datetime(patient)
    session_date = session[:datetime].to_date rescue Date.today
  
		#raise session_date.to_yaml
    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
				EncounterType.find_by_name("HIV Staging").id,patient.id]) rescue nil

    if !hiv_staging.blank?
      (hiv_staging.observations).map do |obs|
        if obs.concept_id == ConceptName.find_by_name('CD4 count datetime').concept_id
					months = (session_date.year * 12 + session_date.month) - (obs.value_datetime.year * 12 + obs.value_datetime.month) rescue nil
					#raise obs.value_datetime.to_yaml
          if months >= 6
            return true
          else
            return false
          end
        end
      end
    end
  end

  def show_alert_refer_to_ART_wing(patient)
		show_alert = false
		refer_to_x_ray = nil
		does_tb_status_obs_exist = false

		session_date = session[:datetime].to_date rescue Date.today
		encounter = Encounter.find(:all, :conditions=>["patient_id = ? \
                    AND encounter_type = ? AND DATE(encounter_datetime) = ? ", patient.id, \
					EncounterType.find_by_name("TB CLINIC VISIT").id, session_date]).last rescue nil
		@date = encounter.encounter_datetime.to_date rescue nil

		if !encounter.nil?
			for obs in encounter.observations do
				if obs.concept_id == ConceptName.find_by_name("Refer to x-ray?").concept_id
					refer_to_x_ray = "#{obs.to_s(["short", "order"]).to_s.split(":")[1].squish}".squish
				elsif obs.concept_id == ConceptName.find_by_name("TB status").concept_id
					does_tb_status_obs_exist = true
				end
			end
		end

		if refer_to_x_ray.upcase == 'NO' && does_tb_status_obs_exist.to_s == false.to_s && PatientService.patient_hiv_status(patient).upcase == 'POSITIVE'
			show_alert = true
		end rescue nil
		show_alert
	end

  def patient_need_sputum_test?(patient_id)
    encounter_date = Encounter.find(:last,
			:conditions => ["encounter_type = ? and patient_id = ?",
				EncounterType.find_by_name("TB Registration").id,
				patient_id]).encounter_datetime rescue ''
    smear_positive_patient = false
    has_no_results = false

    unless encounter_date.blank?
      sputum_results = previous_sputum_results(encounter_date, patient_id)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
					smear_positive_patient = true
					break
        end
      }
      if smear_positive_patient == true
        date_diff = (Date.today - encounter_date.to_date).to_i

        if date_diff > 60 and date_diff < 110
          results = Encounter.find(:last,
						:conditions => ["encounter_type = ? and " \
								"patient_id = ? AND encounter_datetime BETWEEN ? AND ?",
							EncounterType.find_by_name("LAB RESULTS").id,
							patient_id, (encounter_date + 60).to_s, (encounter_date + 110).to_s],
						:include => observations) rescue ''

          if results.blank?
            has_no_results = true
          else
            has_no_results = false
          end

        elsif date_diff > 110 and date_diff < 140
          results = Encounter.find(:last,
						:conditions => ["encounter_type = ? and " \
								"patient_id = ? AND encounter_datetime BETWEEN ? AND ?",
							EncounterType.find_by_name("LAB RESULTS").id,
							patient_id, (encounter_date + 111).to_s, (encounter_date + 140).to_s],
						:include => observations) rescue ''

          if results.blank?
            has_no_results = true
          else
            has_no_results = false
          end

        elsif date_diff > 140
					has_no_results = true
        else
					has_no_results = false
        end
      end
    end

    return false if smear_positive_patient == false
    return false if has_no_results == false
    return true
  end

  def previous_sputum_results(registration_date, patient_id)
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results",
      "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)",
        sputum_concept_names]).map(&:concept_id)
    obs = Observation.find(:all,
      :conditions => ["person_id = ? AND concept_id IN (?) AND date_created < ?",
        patient_id, sputum_concept_ids, registration_date],
      :order => "obs_datetime desc", :limit => 3)
  end

  def given_sputum_results(patient_id)
		@given_results = []
    Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("GIVE LAB RESULTS").id,patient_id]).observations.map{|o| @given_results << o.answer_string.to_s.strip if o.to_s.include?("Laboratory results given to patient")} rescue []
  end

  def get_recent_lab_orders_label(patient_id)
    encounters = Encounter.find(:all,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,patient_id]).last(5)
		observations = []

    encounters.each{|encounter|
      encounter.observations.each{|observation|
				unless observation['concept_id'] == Concept.find_by_name("Workstation location").concept_id
          observations << ["#{ConceptName.find_by_concept_id(observation['value_coded'].to_i).name} : #{observation['date_created'].strftime("%Y-%m-%d") }",
						"#{observation['obs_id']}"]
				end
      }
    }
    return observations
  end

  def recent_lab_orders_label(test_list, patient)
  	patient_bean = PatientService.get_patient(patient.person)
    lab_orders = test_list
    labels = []
    i = 0
    lab_orders.each{|test|
      observation = Observation.find(test.to_i)

      accession_number = "#{observation.accession_number rescue nil}"
			patient_national_id_with_dashes = PatientService.get_national_id_with_dashes(patient)
			if accession_number != ""
				label = 'label' + i.to_s
				label = ZebraPrinter::Label.new(500,165)
				label.font_size = 2
				label.font_horizontal_multiplier = 1
				label.font_vertical_multiplier = 1
				label.left_margin = 300
				label.draw_barcode(70,105,0,1,4,8,50,false,"#{accession_number}")
				label.draw_text("#{patient_bean.name.titleize.delete("'")} #{patient_national_id_with_dashes}",70,45,0,2,1,1)
				label.draw_text("#{observation.name rescue nil} - #{accession_number rescue nil}",70,65,0,2,1,1)
				label.draw_text("#{observation.date_created.strftime("%d-%b-%Y %H:%M")}",70,90,0,2,1,1)
				labels << label
			end

			i = i + 1
    }

		print_labels = []
		label = 0
		while label <= labels.size
			print_labels << labels[label].print(1) if labels[label] != nil
			label = label + 1
		end

		return print_labels
  end

  # Get the any BMI-related alert for this patient
  def current_bmi_alert(patient_weight, patient_height)
    weight = patient_weight
    height = patient_height
    alert = nil
    unless weight == 0 || height == 0
      current_bmi = (weight/(height*height)*10000).round(1);
      if current_bmi <= 18.5 && current_bmi > 17.0
        alert = 'Low BMI: Eligible for counseling'
      elsif current_bmi <= 17.0
        alert = 'Low BMI: Eligible for therapeutic feeding'
      end
    end

    alert
  end

  #moved from the patient model. Needs good testing
  def demographics_label(patient_id)
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    demographics = mastercard_demographics(patient)
    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient.id])

    tb_within_last_two_yrs = "tb within last 2 yrs" unless demographics.tb_within_last_two_yrs.blank?
    eptb = "eptb" unless demographics.eptb.blank?
    pulmonary_tb = "Pulmonary tb" unless demographics.pulmonary_tb.blank?

    cd4_count_date = nil ; cd4_count = nil ; pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'CD4 COUNT DATETIME'
        cd4_count_date = obs.value_datetime.to_date
      when 'CD4 COUNT'
        cd4_count = obs.value_numeric
      when 'IS PATIENT PREGNANT?'
        pregnant = obs.to_s.split(':')[1] rescue nil
      end
    end rescue []

    office_phone_number = PatientService.get_attribute(patient.person, 'Office phone number')
    home_phone_number = PatientService.get_attribute(patient.person, 'Home phone number')
    cell_phone_number = PatientService.get_attribute(patient.person, 'Cell phone number')

    phone_number = office_phone_number if not office_phone_number.downcase == "not available" and not office_phone_number.downcase == "unknown" rescue nil
    phone_number= home_phone_number if not home_phone_number.downcase == "not available" and not home_phone_number.downcase == "unknown" rescue nil
    phone_number = cell_phone_number if not cell_phone_number.downcase == "not available" and not cell_phone_number.downcase == "unknown" rescue nil

    initial_height = PatientService.get_patient_attribute_value(patient, "initial_height")
    initial_weight = PatientService.get_patient_attribute_value(patient, "initial_weight")

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
    label.draw_text("#{demographics.arv_number}",575,30,0,3,1,1,false)
    label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
    label.draw_text("Name:   #{demographics.name} (#{demographics.sex})",25,60,0,3,1,1,false)
    label.draw_text("DOB:    #{PatientService.birthdate_formatted(patient.person)}",25,90,0,3,1,1,false)
    label.draw_text("Phone: #{phone_number}",25,120,0,3,1,1,false)
    if demographics.address.length > 48
      label.draw_text("Addr:  #{demographics.address[0..47]}",25,150,0,3,1,1,false)
      label.draw_text("    :  #{demographics.address[48..-1]}",25,180,0,3,1,1,false)
      last_line = 180
    else
      label.draw_text("Addr:  #{demographics.address}",25,150,0,3,1,1,false)
      last_line = 150
    end

    if !demographics.guardian.nil?
      if last_line == 180 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,210,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,240,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,180,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,180,0,3,1,1,false)
        last_line = 180
      end
    else
      if last_line == 180
        label.draw_text("Guard: None",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180
        label.draw_text("Guard: None}",25,210,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 180
      end
    end

    label.draw_text("TI:    #{demographics.transfer_in ||= 'No'}",25,last_line+=30,0,3,1,1,false)
    label.draw_text("FUP:   (#{demographics.agrees_to_followup})",25,last_line+=30,0,3,1,1,false)


    label2 = ZebraPrinter::StandardLabel.new
    #Vertical lines
    label2.draw_line(25,170,795,3)
    #label data
    label2.draw_text("STATUS AT ART INITIATION",25,30,0,3,1,1,false)
    label2.draw_text("(DSA:#{patient.date_started_art.strftime('%d-%b-%Y') rescue 'N/A'})",370,30,0,2,1,1,false)
    label2.draw_text("#{demographics.arv_number}",580,20,0,3,1,1,false)
    label2.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",25,300,0,1,1,1,false)

    label2.draw_text("RFS: #{demographics.reason_for_art_eligibility}",25,70,0,2,1,1,false)
    label2.draw_text("#{cd4_count} #{cd4_count_date}",25,110,0,2,1,1,false)
    label2.draw_text("1st + Test: #{demographics.hiv_test_date}",25,150,0,2,1,1,false)

    label2.draw_text("TB: #{tb_within_last_two_yrs} #{eptb} #{pulmonary_tb}",380,70,0,2,1,1,false)
    label2.draw_text("KS:#{demographics.ks rescue nil}",380,110,0,2,1,1,false)
    label2.draw_text("Preg:#{pregnant}",380,150,0,2,1,1,false)
    label2.draw_text("#{demographics.first_line_drugs.join(',')[0..32] rescue nil}",25,190,0,2,1,1,false)
    label2.draw_text("#{demographics.alt_first_line_drugs.join(',')[0..32] rescue nil}",25,230,0,2,1,1,false)
    label2.draw_text("#{demographics.second_line_drugs.join(',')[0..32] rescue nil}",25,270,0,2,1,1,false)

    label2.draw_text("HEIGHT: #{initial_height}",570,70,0,2,1,1,false)
    label2.draw_text("WEIGHT: #{initial_weight}",570,110,0,2,1,1,false)
    label2.draw_text("Init Age: #{PatientService.patient_age_at_initiation(patient, demographics.date_of_first_line_regimen) rescue nil}",570,150,0,2,1,1,false)

    line = 190
    extra_lines = []
    label2.draw_text("STAGE DEFINING CONDITIONS",450,190,0,3,1,1,false)

    (demographics.who_clinical_conditions.split(';') || []).each{|condition|
      line+=25
      if line <= 290
        label2.draw_text(condition[0..35],450,line,0,1,1,1,false)
      end
      extra_lines << condition[0..79] if line > 290
    } rescue []

    if line > 310 and !extra_lines.blank?
      line = 30
      label3 = ZebraPrinter::StandardLabel.new
      label3.draw_text("STAGE DEFINING CONDITIONS",25,line,0,3,1,1,false)
      label3.draw_text("#{PatientService.get_patient_identifier(patient, 'ARV Number')}",370,line,0,2,1,1,false)
      label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
      extra_lines.each{|condition|
        label3.draw_text(condition,25,line+=30,0,2,1,1,false)
      } rescue []
    end
    return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" if !extra_lines.blank?
    return "#{label.print(1)} #{label2.print(1)}"
  end

  def patient_transfer_out_label(patient_id)
    date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(patient_id)
    demographics = mastercard_demographics(patient)

    who_stage = demographics.reason_for_art_eligibility 
    initial_staging_conditions = demographics.who_clinical_conditions.split(';')
    destination = demographics.transferred_out_to
   
    label = ZebraPrinter::Label.new(776, 329, 'T')
    label.line_spacing = 0
    label.top_margin = 30
    label.bottom_margin = 30
    label.left_margin = 25
    label.x = 25
    label.y = 30
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
   
    # 25, 30
    # Patient personanl data 
    label.draw_multi_text("#{Location.current_health_center.name} transfer out label", {:font_reverse => true})
    label.draw_multi_text("To #{destination}", {:font_reverse => false}) unless destination.blank?
    label.draw_multi_text("ARV number: #{demographics.arv_number}", {:font_reverse => true})
    label.draw_multi_text("Name: #{demographics.name} (#{demographics.sex.first})\nAge: #{demographics.age}", {:font_reverse => false})

    # Print information on Diagnosis!
    art_start_date = PatientService.date_antiretrovirals_started(patient).strftime("%d-%b-%Y") rescue nil
    label.draw_multi_text("Stage defining conditions", {:font_reverse => true})
    label.draw_multi_text("Reason for starting: #{who_stage}", {:font_reverse => false})
    label.draw_multi_text("ART start date: #{art_start_date}",{:font_reverse => false})
    label.draw_multi_text("Other diagnosis:", {:font_reverse => true})
		# !!!! TODO
    staging_conditions = ""
    count = 1
    initial_staging_conditions.each{|condition|
			if staging_conditions.blank?
				staging_conditions = "(#{count}) #{condition}" unless condition.blank?
			else
				staging_conditions+= " (#{count+=1}) #{condition}" unless condition.blank?
			end
    }
    label.draw_multi_text("#{staging_conditions}", {:font_reverse => false})

    # Print information on current status of the patient transfering out!
    init_ht = "Init HT: #{demographics.init_ht}"                    
    init_wt = "Init WT: #{demographics.init_wt}"

    first_cd4_count = "CD count " + demographics.cd4_count if demographics.cd4_count
    unless demographics.cd4_count_date.blank?
      first_cd4_count_date = "CD count date #{demographics.cd4_count_date.strftime('%d-%b-%Y')}"
    end
    # renamed current status to Initial height/weight as per minimum requirements
    label.draw_multi_text("Initial Height/Weight", {:font_reverse => true})
    label.draw_multi_text("#{init_ht} #{init_wt}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count_date}", {:font_reverse => false})
 
    # Print information on current treatment of the patient transfering out!
    demographics.reg = []
    PatientService.drug_given_before(patient, (date.to_date) + 1.day).uniq.each do |order|
      next unless MedicationService.arv(order.drug_order.drug)
      demographics.reg << order.drug_order.drug.concept.shortname
    end

    label.draw_multi_text("Current ART drugs", {:font_reverse => true})
    label.draw_multi_text("#{demographics.reg}", {:font_reverse => false})
    label.draw_multi_text("Transfer out date:", {:font_reverse => true})
    label.draw_multi_text("#{date.strftime("%d-%b-%Y")}", {:font_reverse => false})

    label.print(1)
  end

  def patient_tb_transfer_out_label(patient_id)
		sputum_results = [['NEGATIVE','NEGATIVE'], ['SCANTY','SCANTY'], ['WEAKLY POSITIVE','1+'], ['MODERATELY POSITIVE','2+'], ['STRONGLY POSITIVE','3+']]
		concept_one = ConceptName.find_by_name("First sputum for AAFB results").concept_id
		concept_two = ConceptName.find_by_name("Second sputum for AAFB results").concept_id
		concept_three = ConceptName.find_by_name("Third sputum for AAFB results").concept_id
		concept_four = ConceptName.find_by_name("Culture(1st) Results").concept_id
		concept_five = ConceptName.find_by_name("Culture(2nd) Results").concept_id
		concept =[]
		culture =[]
		observation = PatientService.recent_sputum_results(patient_id)
		observation.each do |obs|
			next if obs.value_coded.blank?
			concept[0] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_one
			concept[1] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_two
			concept[2] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_three
			culture[0] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_four
			culture[1] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_five
		end
		first = ""
		second = ""
		#raise " yalakwa : #{culture.length}"
		if culture.length > 0
			first = "Culture-1 Results: #{sputum_results.assoc("#{culture[0].upcase}")[1]}"
			second = "Culture-2 Results: #{sputum_results.assoc("#{culture[1].upcase}")[1]}"
		end
			
		if concept.length > 2
			lab_result = []
			h = 0
			(0..2).each do |x|
				if concept[x].to_s != ""
					lab_result[h] = sputum_results.assoc("#{concept[x].upcase}")
					h += 1
				end
			end
			first = "AAFB(1st) results: #{lab_result[0][1] rescue ""}"
			second = "AAFB(2nd) results: #{lab_result[1][1] rescue ""}"
		end
				
		
    date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
		height = PatientService.get_patient_attribute_value(@patient, "current_height")
		weight = PatientService.get_patient_attribute_value(@patient, "initial_weight")
		tb_number = PatientService.get_patient_identifier(patient, "District TB Number")
		
		transferred_out_to = Observation.find(:last, :conditions =>["concept_id = ? and person_id = ?",
        ConceptName.find_by_name("TRANSFER OUT TO").concept_id,patient_bean.patient_id]).value_text rescue ""

    label = ZebraPrinter::Label.new(776, 329, 'T')
    label.line_spacing = 2
    label.top_margin = 30
    label.bottom_margin = 30
    label.left_margin = 25
    label.x = 25
    label.y = 30
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1

    # 25, 30
    # Patient personanl data
    label.draw_multi_text("#{Location.current_health_center.name} transfer out label", {:font_reverse => true})
    label.draw_multi_text("To #{transferred_out_to}", {:font_reverse => false}) unless transferred_out_to.blank?
    label.draw_multi_text("TB number: #{tb_number}", {:font_reverse => true})
    label.draw_multi_text("Name: #{patient_bean.name} (#{patient_bean.sex})\nAge: #{patient_bean.age}", {:font_reverse => false})

    # Print information on Diagnosis!
    tb_start_date = PatientService.sputum_results_by_date(patient_id).first.obs_datetime.strftime("%d-%b-%Y") rescue nil

    label.draw_multi_text("TB start date: #{tb_start_date}",{:font_reverse => false})
		# !!!! TODO
    init_ht = "Init HT: #{height}"
    init_wt = "Init WT: #{weight}"
    # renamed current status to Initial height/weight as per minimum requirements
    label.draw_multi_text("Initial Height/Weight", {:font_reverse => true})
    label.draw_multi_text("#{init_ht} #{init_wt}", {:font_reverse => false})

		label.draw_multi_text("Lab Results", {:font_reverse => true})
		label.draw_multi_text("#{first} #{second}", {:font_reverse => false})
    # Print information on current treatment of the patient transfering out!
    reg = []
    PatientService.drug_given_before(patient, (date.to_date) + 1.day).uniq.each do |order|
      next unless MedicationService.tb_medication(order.drug_order.drug)
      reg << order.drug_order.drug.concept.shortname
    end

    label.draw_multi_text("Current TB drugs", {:font_reverse => true})
    label.draw_multi_text("#{reg}", {:font_reverse => false})
    label.draw_multi_text("Transfer out date: #{date.strftime("%d-%b-%Y")}", {:font_reverse => false})

    label.print(1)
  end


  def patient_lab_orders_label(patient_id)
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    
    lab_orders = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,patient.id]).observations
		labels = []
		i = 0
      
		while i <= lab_orders.size do
			accession_number = "#{lab_orders[i].accession_number rescue nil}"
			patient_national_id_with_dashes = PatientService.get_national_id_with_dashes(patient)
			if accession_number != ""
				label = 'label' + i.to_s
				label = ZebraPrinter::Label.new(500,165)
				label.font_size = 2
				label.font_horizontal_multiplier = 1
				label.font_vertical_multiplier = 1
				label.left_margin = 750
				label.draw_barcode(70,105,0,1,4,8,50,false,"#{accession_number}")
				#label.draw_multi_text("#{patient_bean.name.titleize.delete("'")} #{patient_national_id_with_dashes}")
				#label.draw_multi_text("#{lab_orders[i].name rescue nil} - #{accession_number rescue nil}")
				#label.draw_multi_text("#{lab_orders[i].obs_datetime.strftime("%d-%b-%Y %H:%M")}")
				label.draw_text("#{patient_bean.name.titleize.delete("'")} #{patient_national_id_with_dashes}",70,45,0,2,1,1)
				label.draw_text("#{lab_orders[i].name rescue nil} - #{accession_number rescue nil}",70,65,0,2,1,1)
				label.draw_text("#{lab_orders[i].obs_datetime.strftime("%d-%b-%Y %H:%M")}",70,90,0,2,1,1)
				labels << label
			end
			i = i + 1
		end

		print_labels = []
		label = 0
		while label <= labels.size
			print_labels << labels[label].print(2) if labels[label] != nil
			label = label + 1
		end

		return print_labels
  end

  def patient_filing_number_label(patient, num = 1)
    file = PatientService.get_patient_identifier(patient, 'Filing Number')[0..9]
    file_type = file.strip[3..4]
    version_number=file.strip[2..2]
    number = file
    len = number.length - 5
    number = number[len..len] + "   " + number[(len + 1)..(len + 2)]  + " " +  number[(len + 3)..(number.length)]

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("#{number}",75, 30, 0, 4, 4, 4, false)
    label.draw_text("Filing area #{file_type}",75, 150, 0, 2, 2, 2, false)
    label.draw_text("Version number: #{version_number}",75, 200, 0, 2, 2, 2, false)
    label.print(num)
  end

  def patient_visit_label(patient, date = Date.today)
    result = Location.find(session[:location_id]).name.match(/outpatient/i)

    unless result
      return mastercard_visit_label(patient,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      encs = patient.encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)
      encs.each {|encounter|
        next if encounter.name.upcase == "REGISTRATION"
        next if encounter.name.upcase == "HIV REGISTRATION"
        next if encounter.name.upcase == "HIV STAGING"
        next if encounter.name.upcase == "HIV CLINIC CONSULTATION"
        next if encounter.name.upcase == "VITALS"
        next if encounter.name.upcase == "ART ADHERENCE"
        encounter.to_s.split("<b>").each do |string|
          concept_name = string.split("</b>:")[0].strip rescue nil
          obs_value = string.split("</b>:")[1].strip rescue nil
          next if string.match(/Workstation location/i)
          next if obs_value.blank?
          label.draw_multi_text("#{encounter.name.humanize} - #{concept_name}: #{obs_value}", :font_reverse => false)
        end
      }
      label.print(1)
    end
  end

  def mastercard_demographics(patient_obj)
  	patient_bean = PatientService.get_patient(patient_obj.person)
    visits = Mastercard.new()
    visits.patient_id = patient_obj.id
    visits.arv_number = patient_bean.arv_number
    visits.address = patient_bean.address
    visits.national_id = patient_bean.national_id
    visits.name = patient_bean.name rescue nil
    visits.sex = patient_bean.sex
    visits.age = patient_bean.age
    visits.occupation = PatientService.get_attribute(patient_obj.person, 'Occupation')
    visits.landmark = patient_obj.person.addresses.first.address1
    visits.init_wt = PatientService.get_patient_attribute_value(patient_obj, "initial_weight")
    visits.init_ht = PatientService.get_patient_attribute_value(patient_obj, "initial_height")
    visits.bmi = PatientService.get_patient_attribute_value(patient_obj, "initial_bmi")
    visits.agrees_to_followup = patient_obj.person.observations.recent(1).question("Agrees to followup").all rescue nil
    visits.agrees_to_followup = visits.agrees_to_followup.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_date = patient_obj.person.observations.recent(1).question("Confirmatory HIV test date").all rescue nil
    visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_location = patient_obj.person.observations.recent(1).question("Confirmatory HIV test location").all rescue nil
    location_name = Location.find_by_location_id(visits.hiv_test_location.to_s.split(':')[1].strip).name rescue nil
    visits.hiv_test_location = location_name rescue nil
    visits.guardian = art_guardian(patient_obj) #rescue nil
    visits.reason_for_art_eligibility = PatientService.reason_for_art_eligibility(patient_obj)
    visits.transfer_in = PatientService.is_transfer_in(patient_obj) rescue nil #pb: bug-2677 Made this to use the newly created patient model method 'transfer_in?'
    visits.transfer_in == false ? visits.transfer_in = 'NO' : visits.transfer_in = 'YES'

    transferred_out_details = Observation.find(:last, :conditions =>["concept_id = ? and person_id = ?",
        ConceptName.find_by_name("TRANSFER OUT TO").concept_id,patient_bean.patient_id]) rescue ""

		visits.transferred_out_to = transferred_out_details.value_text if transferred_out_details 
		visits.transferred_out_date = transferred_out_details.obs_datetime if transferred_out_details

		visits.art_start_date = PatientService.patient_art_start_date(patient_bean.patient_id).strftime("%d-%B-%Y") rescue nil

    visits.transfer_in_date = patient_obj.person.observations.recent(1).question("HAS TRANSFER LETTER").all.collect{|o|
			o.obs_datetime if o.answer_string.strip == "YES"}.last rescue nil

    regimens = {}
    regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN','ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN','SECOND LINE ANTIRETROVIRAL REGIMEN']
    regimen_types.map do | regimen |
      concept_member_ids = ConceptName.find_by_name(regimen).concept.concept_members.collect{|c|c.concept_id}
      case regimen
			when 'FIRST LINE ANTIRETROVIRAL REGIMEN'
				regimens[regimen] = concept_member_ids
			when 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN'
				regimens[regimen] = concept_member_ids
			when 'SECOND LINE ANTIRETROVIRAL REGIMEN'
				regimens[regimen] = concept_member_ids
      end
    end

    first_treatment_encounters = []
    encounter_type = EncounterType.find_by_name('DISPENSING').id
    amount_dispensed_concept_id = ConceptName.find_by_name('Amount dispensed').concept_id
    regimens.map do | regimen_type , ids |
      encounter = Encounter.find(:first,
				:joins => "INNER JOIN obs ON encounter.encounter_id = obs.encounter_id",
				:conditions =>["encounter_type=? AND encounter.patient_id = ? AND concept_id = ?
                                 AND encounter.voided = 0 AND value_drug != ?",encounter_type , patient_obj.id , amount_dispensed_concept_id, 297 ],
				:order =>"encounter_datetime")
      first_treatment_encounters << encounter unless encounter.blank?
    end

    visits.first_line_drugs = []
    visits.alt_first_line_drugs = []
    visits.second_line_drugs = []

    first_treatment_encounters.map do | treatment_encounter |
      treatment_encounter.observations.map{|obs|
        next if not obs.concept_id == amount_dispensed_concept_id
        drug = Drug.find(obs.value_drug) if obs.value_numeric > 0
        next if obs.value_numeric <= 0
        drug_concept_id = drug.concept.concept_id
        regimens.map do | regimen_type , concept_ids |
          if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_line_regimen =  PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
            visits.first_line_drugs << drug.concept.shortname
            visits.first_line_drugs = visits.first_line_drugs.uniq rescue []
          elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_alt_line_regimen = PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
            visits.alt_first_line_drugs << drug.concept.shortname
            visits.alt_first_line_drugs = visits.alt_first_line_drugs.uniq rescue []
          elsif regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_second_line_regimen = treatment_encounter.encounter_datetime.to_date
            visits.second_line_drugs << drug.concept.shortname
            visits.second_line_drugs = visits.second_line_drugs.uniq rescue []
          end
        end
      }.compact
    end

    ans = ["Extrapulmonary tuberculosis (EPTB)","Pulmonary tuberculosis within the last 2 years","Pulmonary tuberculosis (current)","Kaposis sarcoma","Pulmonary tuberculosis"]
    staging_ans = patient_obj.person.observations.recent(1).question("WHO STAGES CRITERIA PRESENT").all

    hiv_staging_obs = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient_obj.id]).observations.map(&:concept_id) rescue []

    #if staging_ans.blank?
    #  staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all
   # end

    #if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[3])
    #  visits.ks = 'Yes'
    #else
      ks_concept_id = ConceptName.find_by_name('Kaposis sarcoma').concept_id
      visits.ks = 'Yes' if hiv_staging_obs.include?(ks_concept_id)
    #end

   # if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[1])
   #   visits.tb_within_last_two_yrs = 'Yes'
   # else
      tb_within_2yrs_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis within the last 2 years').concept_id
      visits.tb_within_last_two_yrs = 'Yes' if hiv_staging_obs.include?(tb_within_2yrs_concept_id) 
   # end

   # if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[0])
    #  visits.eptb = 'Yes'
    #else
      eptb_concept_id = ConceptName.find_by_name('Extrapulmonary tuberculosis (EPTB)').concept_id
      visits.eptb = 'Yes' if hiv_staging_obs.include?(eptb_concept_id)
   # end

    #if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[2])
    #  visits.pulmonary_tb = 'Yes'
		#else
      pulm_tuber_cur_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis (current)').concept_id
      visits.pulmonary_tb = 'Yes' if hiv_staging_obs.include?(pulm_tuber_cur_concept_id)
		#end

		#if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[4])
    #  visits.pulmonary_tb = 'Yes'
    #else
      pulm_tuber_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis').concept_id
      visits.pulmonary_tb = 'Yes' if hiv_staging_obs.include?(pulm_tuber_concept_id)
    #end

    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient_obj.id])

    visits.who_clinical_conditions = ""
    (hiv_staging.observations).collect do |obs|
      if CoreService.get_global_property_value('use.extended.staging.questions').to_s == 'true'
        name = obs.to_s.split(':')[0].strip rescue nil
        ans = obs.to_s.split(':')[1].strip rescue nil
        next unless ans.upcase == 'YES'
        visits.who_clinical_conditions = visits.who_clinical_conditions + (name) + "; "
      else
        name = obs.to_s.split(':')[0].strip rescue nil
        next unless name == 'WHO STAGES CRITERIA PRESENT'
        condition = obs.to_s.split(':')[1].strip.humanize rescue nil
        visits.who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
      end
    end rescue []

    visits.cd4_count_date = nil ; visits.cd4_count = nil ; visits.pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name.downcase
			when 'cd4 count datetime'
				visits.cd4_count_date = obs.value_datetime.to_date
			when 'cd4 count'
				visits.cd4_count = "#{obs.value_modifier}#{obs.value_numeric.to_i}"
			when 'is patient pregnant?'
				visits.pregnant = obs.to_s.split(':')[1] rescue nil
			when 'lymphocyte count'
				visits.tlc = obs.answer_string
			when 'lymphocyte count date'
				visits.tlc_date = obs.value_datetime.to_date
      end
    end rescue []

    visits.tb_status_at_initiation = (!visits.tb_status.nil? ? "Curr" :
				(!visits.tb_within_last_two_yrs.nil? ? (visits.tb_within_last_two_yrs.upcase == "YES" ?
						"Last 2yrs" : "Never/ >2yrs") : "Never/ >2yrs"))

    hiv_clinic_registration = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV CLINIC REGISTRATION").id,patient_obj.id])

    (hiv_clinic_registration.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'Ever received ART?'
        visits.ever_received_art = obs.to_s.split(':')[1].strip rescue nil
      when 'Last ART drugs taken'
        visits.last_art_drugs_taken = obs.to_s.split(':')[1].strip rescue nil
      when 'Date ART last taken'
        visits.last_art_drugs_date_taken = obs.value_datetime.to_date rescue nil
      when 'Confirmatory HIV test location'
        visits.first_positive_hiv_test_site = obs.to_s.split(':')[1].strip rescue nil
      when 'ART number at previous location'
        visits.first_positive_hiv_test_arv_number = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test type'
        visits.first_positive_hiv_test_type = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test date'
        visits.first_positive_hiv_test_date = obs.value_datetime.to_date rescue nil
      end
    end rescue []

    visits
  end

  def calculate_bmi(patient_weight, patient_height)
    weight = patient_weight
    height = patient_height
    unless weight == 0 || height == 0
      current_bmi = (weight/(height*height)*10000).round(1);
    end
    current_bmi
  end
  
  def get_current_obs(date, patient, obs)
    concept_id = ConceptName.find_by_name("#{obs}").concept_id
    obs = Observation.find(:last, :conditions => ['person_id = ? and DATE(obs_datetime) <= ? AND concept_id = ?',
                            patient.patient_id, date, concept_id])
  end

  def visits(patient_obj, encounter_date = nil)
    session_date = session[:datetime].blank? ? Date.today : session[:datetime].to_date
    
    transfer_in_date = patient_obj.person.observations.recent(1).question("ART start date").all.collect{|o|
			o.value_datetime }.last.to_date rescue []
    patient_visits = {}  
    yes = ConceptName.find_by_name("YES")
    concept_names = ["APPOINTMENT DATE", "HEIGHT (CM)", 'WEIGHT (KG)',
			"BODY MASS INDEX, MEASURED", "RESPONSIBLE PERSON PRESENT",
			"PATIENT PRESENT FOR CONSULTATION", "TB STATUS",
			"AMOUNT DISPENSED", "ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT",
			"DRUG INDUCED", "AMOUNT OF DRUG BROUGHT TO CLINIC",
			"WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER",
			"CLINICAL NOTES CONSTRUCT", "REGIMEN CATEGORY"]
    concept_ids = ConceptName.find(:all, :conditions => ["name in (?)", concept_names]).map(&:concept_id)
  
    if encounter_date.blank?
      observations = Observation.find(:all,
				:conditions =>["voided = 0 AND person_id = ? AND concept_id IN (?)",
					patient_obj.patient_id, concept_ids],
				:order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    else
      observations = Observation.find(:all,
        :conditions =>["voided = 0 AND person_id = ? AND Date(obs_datetime) = ? AND concept_id IN (?)",
          patient_obj.patient_id,encounter_date.to_date, concept_ids],
        :order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    end
        hiv_program = Program.find_by_name("HIV program").id
        tb_program = Program.find_by_name("TB program").id
        patient_in_programs = PatientProgram.find_by_sql("
                            SELECT * FROM patient_program
                            WHERE patient_id = #{patient_obj.id}
                            AND program_id IN (#{hiv_program}, #{tb_program})
                            AND voided = 0")

        return if patient_in_programs.blank?


		gave_hash = Hash.new(0)
		observations.map do |obs|
			drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
			#if !drug.blank?
				#tb_medical = MedicationService.tb_medication(drug)
				#next if tb_medical == true
			#end
			encounter_name = obs.encounter.name rescue []
			next if encounter_name.blank?
			next if encounter_name.match(/REGISTRATION/i)
			next if encounter_name.match(/HIV STAGING/i)
      
			visit_date = obs.obs_datetime.to_date

      unless transfer_in_date.blank?
        next patient_visits if transfer_in_date == visit_date
      end

			patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
      if patient_visits[visit_date].bmi.blank?
      weight = get_current_obs(visit_date.to_date, patient_obj, "WEIGHT (KG)").to_s.split(':')[1].squish.to_f rescue []
      height = get_current_obs(visit_date.to_date, patient_obj, "HEIGHT (CM)").to_s.split(':')[1].squish.to_f rescue []
      patient_visits[visit_date].bmi = calculate_bmi(weight, height) rescue []
      end
				 
			concept_name = obs.concept.fullname
			if concept_name.upcase == 'APPOINTMENT DATE'
				patient_visits[visit_date].appointment_date = obs.value_datetime
			elsif concept_name.upcase == 'HEIGHT (CM)'
				patient_visits[visit_date].height = obs.answer_string
			elsif concept_name.upcase == 'WEIGHT (KG)'
				patient_visits[visit_date].weight = obs.answer_string
			#elsif concept_name.upcase == 'BODY MASS INDEX, MEASURED'
			#	patient_visits[visit_date].bmi = obs.answer_string
			elsif concept_name == 'RESPONSIBLE PERSON PRESENT' or concept_name == 'PATIENT PRESENT FOR CONSULTATION'
				patient_visits[visit_date].visit_by = '' if patient_visits[visit_date].visit_by.blank?
				patient_visits[visit_date].visit_by+= "P" if obs.to_s.squish.match(/Patient present for consultation: Yes/i)
				patient_visits[visit_date].visit_by+= "G" if obs.to_s.squish.match(/Responsible person present: Yes/i)
			#elsif concept_name.upcase == 'TB STATUS'
			#	status = tb_status(patient_obj).upcase rescue nil
			#	patient_visits[visit_date].tb_status = status
			#	patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
			#	patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
			#	patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
			#	patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
			#	patient_visits[visit_date].tb_status = 'Rx' if status == 'CURRENTLY IN TREATMENT'

			elsif concept_name.upcase == 'AMOUNT DISPENSED'

				drug = Drug.find(obs.value_drug) rescue nil
				#tb_medical = MedicationService.tb_medication(drug)
				#next if tb_medical == true
				next if drug.blank?
				drug_name = drug.concept.shortname rescue drug.name
				if drug_name.match(/Cotrimoxazole/i) || drug_name.match(/CPT/i)
					patient_visits[visit_date].cpt += obs.value_numeric unless patient_visits[visit_date].cpt.blank?
					patient_visits[visit_date].cpt = obs.value_numeric if patient_visits[visit_date].cpt.blank?
				else
					tb_medical = MedicationService.tb_medication(drug)
					patient_visits[visit_date].gave = [] if patient_visits[visit_date].gave.blank?
					patient_visits[visit_date].gave << [drug_name,obs.value_numeric]
					drugs_given_uniq = Hash.new(0)
					(patient_visits[visit_date].gave || {}).each do |drug_given_name,quantity_given|
						drugs_given_uniq[drug_given_name] += quantity_given
					end
					patient_visits[visit_date].gave = []
					(drugs_given_uniq || {}).each do |drug_given_name,quantity_given|
						patient_visits[visit_date].gave << [drug_given_name,quantity_given]
					end
				end
				#if !drug.blank?
				#	tb_medical = MedicationService.tb_medication(drug)
					#patient_visits[visit_date].ipt = [] if patient_visits[visit_date].ipt.blank?
					#patient_visits[visit_date].tb_status = "tb medical" if tb_medical == true
					#raise patient_visits[visit_date].tb_status.to_yaml
				#end

			elsif concept_name.upcase == 'REGIMEN CATEGORY'
				#patient_visits[visit_date].reg = 'Unknown' if obs.value_coded == ConceptName.find_by_name("Unknown antiretroviral drug").concept_id
				patient_visits[visit_date].reg = obs.value_text if !patient_visits[visit_date].reg

			elsif concept_name.upcase == 'DRUG INDUCED'
				symptoms = obs.to_s.split(':').map do | sy |
					sy.sub(concept_name,'').strip.capitalize
				end rescue []
				patient_visits[visit_date].s_eff = symptoms.join("<br/>") unless symptoms.blank?
            
			elsif concept_name.upcase == 'AMOUNT OF DRUG BROUGHT TO CLINIC'
				drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
				#tb_medical = MedicationService.tb_medication(drug) unless drug.nil?
				#next if tb_medical == true
				next if drug.blank?
				drug_name = drug.concept.shortname rescue drug.name
				patient_visits[visit_date].pills = [] if patient_visits[visit_date].pills.blank?
				patient_visits[visit_date].pills << [drug_name,obs.value_numeric] rescue []
            
			elsif concept_name.upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
        
				drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
				#tb_medical = MedicationService.tb_medication(drug) unless drug.nil?
				#next if tb_medical == true
				next if  obs.to_s.split(':')[1].to_i.blank?
				patient_visits[visit_date].adherence = [] if patient_visits[visit_date].adherence.blank?
        #raise obs.order.drug_order.to_yaml
				patient_visits[visit_date].adherence << [(Drug.find(obs.order.drug_order.drug_inventory_id).name rescue ''),((obs.to_s.split(':')[1] + '%') rescue '')]
			elsif concept_name == 'CLINICAL NOTES CONSTRUCT' || concept_name == 'Clinical notes construct'
				patient_visits[visit_date].notes+= '<br/>' + obs.value_text unless patient_visits[visit_date].notes.blank?
				patient_visits[visit_date].notes = obs.value_text if patient_visits[visit_date].notes.blank?
			end
		end

    #patients currents/available states (patients outcome/s)
    program_id = Program.find_by_name('HIV PROGRAM').id
    if encounter_date.blank?
      patient_states = PatientState.find(:all,
				:joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
				:conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
					program_id,patient_obj.patient_id],:order => "patient_state_id ASC")
    else
      patient_states = PatientState.find(:all,
				:joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
				:conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND start_date = ? AND p.patient_id =?",
					program_id,encounter_date.to_date,patient_obj.patient_id],:order => "patient_state_id ASC")
    end  

    all_patient_states = []
    patient_states.each do |state|
      state_name = state.program_workflow_state.concept.fullname rescue 'Unknown state'
      all_patient_states << [state_name, state.start_date]
    end
 
    defaulted_dates = PatientService.patient_defaulted_dates(patient_obj, session_date) rescue nil

    if defaulted_dates
      defaulted_dates.each do |pat_def_date|  
        state_name = 'Defaulter'
        all_patient_states << [state_name, pat_def_date]
      end
    end

#=begin
    all_patient_states.each do |outcome, outcome_date| 
      visit_date = outcome_date.to_date rescue nil
      next if visit_date.blank?
      patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
      patient_visits[visit_date].outcome = outcome
      if patient_visits[visit_date].outcome.match(/transferred in/i)
         patient_visits[visit_date].outcome = "ON ARV" 
      end
      patient_visits[visit_date].date_of_outcome = outcome_date

    end

#=end

    patient_visits.sort.each do |visit_date,data|
      next if visit_date.blank?
     # patient_visits[visit_date].outcome = hiv_state(patient_obj,visit_date)
      #patient_visits[visit_date].date_of_outcome = visit_date

			status = tb_status(patient_obj, visit_date).upcase rescue nil
			patient_visits[visit_date].tb_status = status
			patient_visits[visit_date].tb_status = 'unknown' if status == 'MISSING'
			patient_visits[visit_date].tb_status = 'unknown' if status == 'UNKNOWN'
			patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
			patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
			patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
			patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
			patient_visits[visit_date].tb_status = 'Rx' if status == 'CURRENTLY IN TREATMENT'
    end

    unless encounter_date.blank?
      outcome = patient_visits[encounter_date].outcome rescue nil
      if outcome.blank?
        state = PatientState.find(:first,
					:joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
					:conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
						program_id,patient_obj.patient_id],:order => "date_enrolled DESC,start_date DESC")

        patient_visits[encounter_date] = Mastercard.new() if patient_visits[encounter_date].blank?
        patient_visits[encounter_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
        if patient_visits[encounter_date].outcome.match(/transferred in/i)
          patient_visits[encounter_date].outcome = "ON ARV" 
        end
        patient_visits[encounter_date].date_of_outcome = state.start_date rescue nil
      end
    end

    patient_visits
  end  


	def tb_status(patient, visit_date = Date.today)
	  state = Concept.find(Observation.find(:first, :order => "obs_datetime DESC, date_created DESC", :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) <= ? AND value_coded IS NOT NULL", patient.id, ConceptName.find_by_name("TB STATUS").concept_id, visit_date.to_date ]).value_coded).fullname rescue "Unknown"

    program_id = Program.find_by_name('TB PROGRAM').id
     patient_state = PatientState.find(:first,
       :joins => "INNER JOIN patient_program p
       ON p.patient_program_id = patient_state.patient_program_id",
       :conditions =>["patient_state.voided = 0 AND p.voided = 0
       AND p.program_id = ? AND DATE(start_date) <= DATE('#{visit_date}') AND p.patient_id =?",
       program_id,patient.id],
       :order => "start_date DESC")

    return state if patient_state.blank?
    return ConceptName.find_by_concept_id(patient_state.program_workflow_state.concept_id).name

  end

	def hiv_state(patient_obj,visit_date)
     program_id = Program.find_by_name('HIV PROGRAM').id
     patient_state = PatientState.find(:first,
       :joins => "INNER JOIN patient_program p
       ON p.patient_program_id = patient_state.patient_program_id",
       :conditions =>["patient_state.voided = 0 AND p.voided = 0
       AND p.program_id = ? AND DATE(start_date) <= DATE('#{visit_date}') AND p.patient_id =?",
       program_id,patient_obj.id],
       :order => "start_date DESC")

		#patient_state = PatientState.find(:last,
     #                         :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
     #                         :conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.patient_id = #{patient_obj.id} AND DATE(start_date) <= DATE('#{visit_date}') AND p.program_id = #{program_id}"],:order => "start_date DESC")
     return if patient_state.blank?
     ConceptName.find_by_concept_id(patient_state.program_workflow_state.concept_id).name
  end

	def definitive_state_date(patient, program) #written to avoid causing conflicts in other methods
		state_date = ""
		programs = patient.patient_programs.all rescue []
   
		programs.each do |prog|
			if prog.program.name.upcase == program and program == "HIV PROGRAM"
        program_state = ProgramWorkflowState.find_state(prog.patient_states.last.state).concept.fullname.downcase rescue nil
				if ! program_state.blank?
            if  program_state.match(/pre-art/i)
                state_date = prog.date_enrolled
            end
        end
			end
			if prog.program.name.upcase == program and program != "HIV PROGRAM" and program != "ON ARV"
				state_date = prog.date_enrolled
			end
			if prog.program.name.upcase == "HIV PROGRAM" and program == "ON ARV"
        program_state = ProgramWorkflowState.find_state(prog.patient_states.last.state).concept.fullname.downcase rescue nil
				if ! program_state.blank?
            if program_state.match(/on antiretrovirals/i)
                state_date = prog.date_enrolled
            end
        end
			end
		end
		state_date
	end
	
  def mastercard_visit_label(patient, date = Date.today)
  	patient_bean = PatientService.get_patient(patient.person)
    visit = visits(patient, date)[date] rescue {}

		owner = " :Patient visit"

		if PatientService.patient_and_guardian_present?(patient.id) == false and PatientService.guardian_present?(patient.id) == true
			owner = " :Guardian Visit"
		end

    return if visit.blank?
    visit_data = mastercard_visit_data(visit)
    arv_number = patient_bean.arv_number || patient_bean.national_id
    pill_count = visit.pills.collect{|c|c.join(",")}.join(' ') rescue nil

    label = ZebraPrinter::StandardLabel.new
    #label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient_bean.name}(#{patient_bean.sex}) #{owner}",25,60,0,3,1,1,false)
    label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}",25,95,0,2,1,1,false)
    label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    label.draw_text("#{adherence_to_show(visit.adherence).gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    label.draw_text("#{visit_data['next_appointment']}",577,190,0,2,1,1,false) if visit_data['next_appointment']
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      #bold = true if key.include?("side_eff") and data !="None"
      #bold = true if key.include?("arv_given")
      starting_index = values.first.to_i
      starting_line = start_line
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = s
      
