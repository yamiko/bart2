class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def show
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
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
    # render :template => 'dashboards/overview', :layout => 'dashboard'

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

     @location = Location.find(session[:location_id]).name rescue ""
     if @location.downcase == "outpatient" || params[:source]== 'opd'
        render :template => 'dashboards/opdtreatment_dashboard', :layout => false
     else
        @task = main_next_task(Location.current_location,@patient,session_date)
        @hiv_status = patient_hiv_status(@patient)
        @reason_for_art_eligibility = reason_for_art_eligibility(@patient)

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
        if User.current_user.user_roles.map{|r|r.role}.join(',').match(/Registration|Clerk/i)
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
    @reason_for_art_eligibility = reason_for_art_eligibility(@patient)
    
    # render :template => 'dashboards/treatment', :layout => 'dashboard'
    render :template => 'dashboards/dispension_tab', :layout => false
  end

  def history_treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
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
    # render :template => 'dashboards/treatment', :layout => 'dashboard'
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
      redirect_to next_form_to and return if next_form.match(/Reception/i)
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
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

    if use_filing_number and not patient.get_identifier('Filing Number').blank?
      @links << ["Filing Number (Print)","/patients/print_filing_number/#{patient.id}"]
    end 

    if use_filing_number and patient.get_identifier('Filing Number').blank?
      @links << ["Filing Number (Create)","/patients/set_filing_number/#{patient.id}"]
    end 

    if GlobalProperty.use_user_selected_activities
      @links << ["Change User Activities","/user/activities/#{User.current_user.id}?patient_id=#{patient.id}"]
    end

    @links << ["Recent Lab Orders Label","/patients/recent_lab_orders?patient_id=#{patient.id}"]
    @links << ["Transfer out label (Print)","/patients/print_transfer_out_label/#{patient.id}"]

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
   
  def patient_demographics_label
    print_string = demographics_label(params[:id])
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
  
  def national_id_label
    print_string = patient_national_id_label(@patient) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_lab_orders
    print_and_redirect("/patients/lab_orders_label/?patient_id=#{@patient.id}", next_task(@patient))
  end

  def lab_orders_label
    label_commands = patient_lab_orders_label(@patient.id)
    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbs", :disposition => "inline")
  end

  def filing_number_label
    patient = Patient.find(params[:id])
    label_commands = patient_filing_number_label(patient)
    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def filing_number_and_national_id
    patient = Patient.find(params[:patient_id])
    label_commands = patient_national_id_label(patient) + patient_filing_number_label(patient)

    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def visit_label
    print_string = patient_visit_label(@patient) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
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

  def mastercard_menu
    render :layout => "menu"
    @patient_id = params[:patient_id]
  end

  def mastercard
    @type = params[:type]
    
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false
    
    if params[:patient_id].blank?

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

    render :layout => false
    
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

      # elsif session[:mastercard_ids].length.to_i != 0
      #  @patient_id = params[:patient_id]
      #  @data_demo = mastercard_demographics(Patient.find(@patient_id))
      #  @visits = visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
      @visits = visits(Patient.find(@patient_id))
    end
    render :layout => false
  end

  def visit
    @patient_id = params[:patient_id] 
    @date = params[:date].to_date
    @patient = Patient.find(@patient_id)
    @visits = visits(@patient,@date)
    render :layout => "menu"
  end

  def next_available_arv_number
    next_available_arv_number = PatientIdentifier.next_available_arv_number
    render :text => next_available_arv_number.gsub(PatientIdentifier.site_prefix,'').strip rescue nil
  end
  
  def assigned_arv_number
    assigned_arv_number = PatientIdentifier.find(:all,:conditions => ["voided = 0 AND identifier_type = ?",
        PatientIdentifierType.find_by_name("ARV Number").id]).collect{|i|
      i.identifier.gsub(PatientIdentifier.site_prefix,'').strip.to_i
    } rescue nil
    render :text => assigned_arv_number.sort.to_json rescue nil 
  end

  def mastercard_modify
    if request.method == :get
      @patient_id = params[:id]
      @patient = Patient.find(params[:id])
      @edit_page = Patient.edit_mastercard_attribute(params[:field].to_s)

      if @edit_page == "guardian"
        @guardian = {}
        @patient.person.relationships.map{|r| @guardian[Person.find(r.person_b).name] = Person.find(r.person_b).id.to_s;'' }
        if  @guardian == {}
          redirect_to :controller => "relationships" , :action => "search",:patient_id => @patient_id
        end
      end
    else
      @patient_id = params[:patient_id]
      Patient.save_mastercard_attribute(params)
      if params[:source].to_s == "opd"
        redirect_to "/patients/opdcard/#{@patient_id}" and return

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
    patient.set_filing_number

    archived_patient = patient.patient_to_be_archived
    message = patient_printing_message(patient,archived_patient,true)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/patients/show/#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/patients/show/#{patient.id}")
    end
  end

  def set_new_filing_number
    patient = Patient.find(params[:id])
    patient.set_new_filing_number

    archived_patient = patient.patient_to_be_archived
    message = patient_printing_message(patient,archived_patient)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/people/confirm?found_person_id=#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/people/confirm?found_person_id=#{patient.id}")
    end
  end

  def export_to_csv
    ( Patient.find(:all,:limit => 10) || [] ).each do | patient |
      csv_string = FasterCSV.generate do |csv|
        # header row
        csv << ["ARV number", "National ID"]
        csv << [patient.arv_number, patient.national_id]
        csv << ["Name", "Age","Sex","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]
        transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
        transfer_in.blank? == true ? transfer_in = 'NO' : transfer_in = 'YES'
        csv << [patient.name,patient.person.age, patient.person.sex,get_patient_attribute_value(patient, "initial_weight"),get_patient_attribute_value(patient, "initial_height"),get_patient_attribute_value(patient, "initial_bmi"),transfer_in]
        csv << ["Location", "Land-mark","Occupation","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]

=begin
        # data rows
        @users.each do |user|
          csv << [user.id, user.username, user.salt]
        end
=end
      end
      # send it to the browsah
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
          session[:user_id].to_s + ".pdf http://" + request.env["HTTP_HOST"] + "\"/patients/mastercard_printable?patient_id=" +
          @patient.id.to_s + "\"\n"
      }

      t2 = Thread.new{
        sleep(5)
        Kernel.system "lpr /tmp/output-" + session[:user_id].to_s + ".pdf\n"
      }

      t3 = Thread.new{
        sleep(10)
        Kernel.system "rm /tmp/output-" + session[:user_id].to_s + ".pdf\n"
      }

    end

    redirect_to "/patients/mastercard?patient_id=#{@patient.id}" and return
  end
  
  def demographics
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
    
    @hiv_status = patient_hiv_status(@patient)
    @reason_for_art_eligibility = reason_for_art_eligibility(@patient)

    render :template => 'patients/index', :layout => false
  end

  def overview
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
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

    render :template => 'dashboards/overview_tab', :layout => false
  end

  def visit_history
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
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
    previous_encounters = Encounter.find(:all,
              :conditions => ["encounter.voided = ? and patient_id = ?", 0, patient_id],
              :include => [:observations]
            )

    return previous_encounters
  end

  def past_visits_summary
    @previous_visits  = get_previous_encounters(params[:patient_id])

    @encounter_dates = @previous_visits.map{|encounter| encounter.encounter_datetime.to_date}.uniq.reverse.first(6) rescue []

    @past_encounter_dates = []

    @encounter_dates.each do |encounter|
      @past_encounter_dates << encounter if encounter < (session[:datetime].to_date rescue Date.today.to_date)
    end

    render :template => 'dashboards/past_visits_summary_tab', :layout => false
  end

  def treatment_dashboard
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
    @reason_for_art_eligibility = reason_for_art_eligibility(@patient)
    
    render :template => 'dashboards/treatment_dashboard', :layout => false
  end

  def guardians_dashboard
    @reason_for_art_eligibility = reason_for_art_eligibility(@patient)
    render :template => 'dashboards/relationships_dashboard', :layout => false
  end

  def programs_dashboard
    @reason_for_art_eligibility = reason_for_art_eligibility(@patient)
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
    @visits = visits(@patient)   # (@patient, (session[:datetime].to_date rescue Date.today))
    @patient_age_at_initiation = patient_age_at_initiation(@patient,
                                              @patient.art_start_date)
    render :layout => false
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
    count = Observation.count(:all,
            :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
            :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
            concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')])
    count = count.values unless count.blank?
    count = '0' if count.blank?
    render :text => count
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
    @task = Task.find(params[:task_id])
    render :template => 'dashboards/next_task_description', :layout => false
  end

  def tb_treatment_card # to look at later - To test that is
    render :layout => 'menu'
  end

  def alerts(patient, session_date = Date.today) 
    # next appt
    # adherence
    # drug auto-expiry
    # cd4 due

    alerts = []

    type = EncounterType.find_by_name("APPOINTMENT")
    next_appt = Observation.find(:first,:order => "encounter_datetime DESC,encounter.date_created DESC",
               :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
               :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?",
               ConceptName.find_by_name('Appointment date').concept_id,
               type.id,patient.id]).to_s rescue nil
    alerts << ('Next ' + next_appt).capitalize unless next_appt.blank?

    encounter_dates = Encounter.find_by_sql("SELECT * FROM encounter WHERE patient_id = #{patient.id} AND encounter_type IN (" +
        ("SELECT encounter_type_id FROM encounter_type WHERE name IN ('VITALS', 'TREATMENT', " +
          "'HIV RECEPTION', 'HIV STAGING', 'ART VISIT', 'DISPENSING')") + ")").collect{|e|
      e.encounter_datetime.strftime("%Y-%m-%d")
    }.uniq

    missed_appt = patient.encounters.find_last_by_encounter_type(type.id, 
      :conditions => ["NOT (DATE_FORMAT(encounter_datetime, '%Y-%m-%d') IN (?)) AND encounter_datetime < NOW()",
        encounter_dates], :order => "encounter_datetime").observations.last.to_s rescue nil
    alerts << ('Missed ' + missed_appt).capitalize unless missed_appt.blank?

    @adherence_level = ConceptName.find_by_name('What was the patients adherence for this drug order').concept_id
    type = EncounterType.find_by_name("ART ADHERENCE")

    patient.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.map do |adh|
      if adh.concept_id == @adherence_level
        if (adh.value_numeric.to_i < 95 || adh.value_numeric.to_i > 105)
          alerts << "Adherence: #{adh.order.drug_order.drug.name} (#{adh.value_numeric}%)"
        end
      end
    end rescue []

    type = EncounterType.find_by_name("DISPENSING")
    patient.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.each do | obs |
      next if obs.order.blank? and obs.order.auto_expire_date.blank?
      alerts << "Auto expire date: #{obs.order.drug_order.drug.name} #{obs.order.auto_expire_date.to_date.strftime('%d-%b-%Y')}"
    end rescue []

    # BMI alerts
    if patient.person.age >= 15
      bmi_alert = current_bmi_alert(get_patient_attribute_value(patient, "current_weight"), get_patient_attribute_value(patient, "current_height"))
      alerts << bmi_alert if bmi_alert
    end
    
    program_id = Program.find_by_name("HIV PROGRAM").id
    location_id = Location.current_health_center.location_id

    patient_hiv_program = PatientProgram.find(:all,:conditions =>["voided = 0 AND patient_id = ? AND program_id = ? AND location_id = ?", patient.id , program_id, location_id])

    hiv_status = patient_hiv_status(patient)
    alerts << "HIV Status : #{hiv_status} more than 3 months" if ("#{hiv_status.strip}" == 'Negative' && months_since_last_hiv_test(patient.id) > 3)
    alerts << "Patient not on ART" if (("#{hiv_status.strip}" == 'Positive') && !patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) ||
                                                          ((patient.patient_programs.current.local.map(&:program).map(&:name).include?('HIV PROGRAM')) && (ProgramWorkflowState.find_state(patient_hiv_program.last.patient_states.last.state).concept.fullname != "On antiretrovirals"))
    alerts << "HIV Status : #{hiv_status}" if "#{hiv_status.strip}" == 'Unknown'
    alerts << "Lab: Expecting submission of sputum" unless sputum_orders_without_submission(patient.id).empty?
    alerts << "Lab: Waiting for sputum results" if recent_sputum_results(patient.id).empty? && !recent_sputum_submissions(patient.id).empty?
    alerts << "Lab: Results not given to patient" if !recent_sputum_results(patient.id).empty? && given_sputum_results(patient.id).to_s != "Yes"
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

        if refer_to_x_ray.upcase == 'NO' && does_tb_status_obs_exist.to_s == false.to_s && patient_hiv_status(patient).upcase == 'POSITIVE'
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
    lab_orders = test_list
    labels = []
    i = 0
    lab_orders.each{|test|
      observation = Observation.find(test.to_i)

      accession_number = "#{observation.accession_number rescue nil}"

        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::Label.new(500,165)
          label.font_size = 2
          label.font_horizontal_multiplier = 1
          label.font_vertical_multiplier = 1
          label.left_margin = 300
          label.draw_barcode(50,105,0,1,4,8,50,false,"#{accession_number}")
          label.draw_multi_text("#{patient.person.name.titleize.delete("'")} #{patient.national_id_with_dashes}")
          label.draw_multi_text("#{observation.name rescue nil} - #{accession_number rescue nil}")
          label.draw_multi_text("#{observation.date_created.strftime("%d-%b-%Y %H:%M")}")
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

    office_phone_number = patient.person.get_attribute('Office phone number')
    home_phone_number = patient.person.get_attribute('Home phone number')
    cell_phone_number = patient.person.get_attribute('Cell phone number')

    phone_number = office_phone_number if not office_phone_number.downcase == "not available" and not office_phone_number.downcase == "unknown" rescue nil
    phone_number= home_phone_number if not home_phone_number.downcase == "not available" and not home_phone_number.downcase == "unknown" rescue nil
    phone_number = cell_phone_number if not cell_phone_number.downcase == "not available" and not cell_phone_number.downcase == "unknown" rescue nil

    initial_height = get_patient_attribute_value(patient, "initial_height")
    initial_weight = get_patient_attribute_value(patient, "initial_weight")

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
    label.draw_text("#{demographics.arv_number}",575,30,0,3,1,1,false)
    label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
    label.draw_text("Name:   #{demographics.name} (#{demographics.sex})",25,60,0,3,1,1,false)
    label.draw_text("DOB:    #{patient.person.birthdate_formatted}",25,90,0,3,1,1,false)
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
=begin
     label2.draw_line(45,40,5,242)
     label2.draw_line(805,40,5,242)
     label2.draw_line(365,40,5,242)
     label2.draw_line(575,40,5,242)

     #horizontal lines
     label2.draw_line(45,40,795,3)
     label2.draw_line(45,80,795,3)
     label2.draw_line(45,120,795,3)
     label2.draw_line(45,200,795,3)
     label2.draw_line(45,240,795,3)
     label2.draw_line(45,280,795,3)
=end
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
    label2.draw_text("Init Age: #{patient_age_at_initiation(patient, demographics.date_of_first_line_regimen) rescue nil}",570,150,0,2,1,1,false)

    line = 190
    extra_lines = []
    label2.draw_text("STAGE DEFINING CONDITIONS",450,190,0,3,1,1,false)
    (hiv_staging.observations).each{|obs|
      name = obs.to_s.split(':')[0].strip rescue nil
      condition = obs.to_s.split(':')[1].strip.humanize rescue nil
      next unless name == 'WHO STAGES CRITERIA PRESENT'
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
      label3.draw_text("#{patient.arv_number}",370,line,0,2,1,1,false)
      label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
      extra_lines.each{|condition|
        label3.draw_text(condition,25,line+=30,0,2,1,1,false)
      } rescue []
    end
    return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" if !extra_lines.blank?
    return "#{label.print(1)} #{label2.print(1)}"
  end

  def patient_transfer_out_label(patient_id)
    patient = Patient.find(patient_id)
    demographics = mastercard_demographics(patient)
    demographics_str = []
    demographics_str << "Name: #{demographics.name}"
    demographics_str << "DOB: #{patient.person.birthdate}"
    demographics_str << "DOB-E: #{patient.person.birthdate_estimated}"
    demographics_str << "Sex: #{demographics.sex}"
    demographics_str << "Guardian name: #{demographics.guardian}"
    demographics_str << "ARV number: #{demographics.arv_number}"
    demographics_str << "National ID: #{demographics.national_id}"

    demographics_str << "Address: #{demographics.address}"
    demographics_str << "FU: #{demographics.agrees_to_followup}"
    demographics_str << "1st alt line: #{demographics.alt_first_line_drugs.join(':')}"
    demographics_str << "BMI: #{demographics.bmi}"
    demographics_str << "CD4: #{demographics.cd4_count}"
    demographics_str << "CD4 date: #{demographics.cd4_count_date}"
    demographics_str << "1st line date: #{demographics.date_of_first_line_regimen}"
    demographics_str << "ERA: #{demographics.ever_received_art}"
    demographics_str << "1st line: #{demographics.first_line_drugs.join(':')}"
    demographics_str << "1st pos HIV test date: #{demographics.first_positive_hiv_test_date}"

    demographics_str << "1st pos HIV test site: #{demographics.first_positive_hiv_test_site}"
    demographics_str << "1st pos HIV test type: #{demographics.first_positive_hiv_test_type}"
    demographics_str << "Test date: #{demographics.hiv_test_date.gsub('/','-')}" if demographics.hiv_test_date
    demographics_str << "Test loc: #{demographics.hiv_test_location}"
    demographics_str << "Init HT: #{demographics.init_ht}"
    demographics_str << "Init WT: #{demographics.init_wt}"
    demographics_str << "Landmark: #{demographics.landmark}"
    demographics_str << "Occupation: #{demographics.occupation}"
    demographics_str << "Preg: #{demographics.pregnant}" if patient.person.gender == 'F'
    demographics_str << "SR: #{demographics.reason_for_art_eligibility}"
    demographics_str << "2nd line: #{demographics.second_line_drugs}"
    demographics_str << "TB status: #{demographics.tb_status_at_initiation}"
    demographics_str << "TI: #{demographics.transfer_in}"
    demographics_str << "TI date: #{demographics.transfer_in_date}"


    visits = visits(patient) ; count = 0 ; visit_str = nil
    (visits || {}).sort{|a,b| b[0].to_date<=>a[0].to_date}.each do | date,visit |
      break if count > 3
      visit_str = "Visit date: #{date}" if visit_str.blank?
      visit_str += ";Visit date: #{date}" unless visit_str.blank?
      visit_str += ";wt: #{visit.weight}" if visit.weight
      visit_str += ";ht: #{visit.height}" if visit.height
      visit_str += ";bmi: #{visit.bmi}" if visit.bmi
      visit_str += ";Outcome: #{visit.outcome}" if visit.outcome
      visit_str += ";Regimen: #{visit.reg}" if visit.reg
      visit_str += ";Adh: #{visit.adherence.join(' ')}" if visit.adherence
      visit_str += ";TB status: #{visit.tb_status}" if visit.tb_status
      gave = nil
      (visit.gave.uniq || []).each do | name , quantity |
        gave += "  #{name} (#{quantity})" unless gave.blank?
        gave = ";Gave: #{name} (#{quantity})" if gave.blank?
      end rescue []
      visit_str += gave unless gave.blank?
      count+=1
      demographics_str << visit_str
    end

    label = ZebraPrinter::StandardLabel.new
    label.draw_2D_barcode(80,20,'P',700,600,'x2','y7','l100','r100','f0','s5',"#{demographics_str.join(',').gsub('/','')}")
    label.print(1)
  end

  def patient_lab_orders_label(patient_id)
    patient = Patient.find(patient_id)
    lab_orders = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,patient.id]).observations
      labels = []
      i = 0

      while i <= lab_orders.size do
        accession_number = "#{lab_orders[i].accession_number rescue nil}"

        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::Label.new(500,165)
          label.font_size = 2
          label.font_horizontal_multiplier = 1
          label.font_vertical_multiplier = 1
          label.left_margin = 300
          label.draw_barcode(50,105,0,1,4,8,50,false,"#{accession_number}")
          label.draw_multi_text("#{patient.person.name.titleize.delete("'")} #{patient.national_id_with_dashes}")
          label.draw_multi_text("#{lab_orders[i].name rescue nil} - #{accession_number rescue nil}")
          label.draw_multi_text("#{lab_orders[i].obs_datetime.strftime("%d-%b-%Y %H:%M")}")
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
    file = patient.get_identifier('Filing Number')[0..9]
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
    result = Location.current_location.name.match(/outpatient/i).nil?

    if result == false
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
        next if encounter.name.humanize == "Registration"
        label.draw_multi_text("#{encounter.name.humanize}: #{encounter.to_s}", :font_reverse => false)
      }
      label.print(1)
    end
  end

  def mastercard_demographics(patient_obj)
    visits = Mastercard.new()
    visits.patient_id = patient_obj.id
    visits.arv_number = patient_obj.get_identifier('ARV Number')
    visits.address = patient_obj.person.addresses.first.city_village
    visits.national_id = patient_obj.national_id
    visits.name = patient_obj.person.names.first.given_name + ' ' + patient_obj.person.names.first.family_name rescue nil
    visits.sex = patient_obj.gender
    visits.age = patient_obj.person.age
    visits.occupation = patient_obj.person.get_attribute('Occupation')
    visits.landmark = patient_obj.person.addresses.first.address1
    visits.init_wt = get_patient_attribute_value(patient_obj, "initial_weight")
    visits.init_ht = get_patient_attribute_value(patient_obj, "initial_height")
    visits.bmi = get_patient_attribute_value(patient_obj, "initial_bmi")
    visits.agrees_to_followup = patient_obj.person.observations.recent(1).question("Agrees to followup").all rescue nil
    visits.agrees_to_followup = visits.agrees_to_followup.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_date = patient_obj.person.observations.recent(1).question("Confirmatory HIV test date").all rescue nil
    visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_location = patient_obj.person.observations.recent(1).question("Confirmatory HIV test location").all rescue nil
    visits.hiv_test_location = visits.hiv_test_location.to_s.split(':')[1].strip rescue nil
    visits.guardian = patient_obj.art_guardian rescue nil
    visits.reason_for_art_eligibility = patient_obj.reason_for_art_eligibility
    visits.transfer_in = patient_obj.transfer_in? rescue nil #pb: bug-2677 Made this to use the newly created patient model method 'transfer_in?'
    visits.transfer_in == false ? visits.transfer_in = 'NO' : visits.transfer_in = 'YES'

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
                                 AND encounter.voided = 0",encounter_type , patient_obj.id , amount_dispensed_concept_id ],
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
        drug_concept_id = drug.concept.concept_id
        regimens.map do | regimen_type , concept_ids |
          if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_line_regimen = treatment_encounter.encounter_datetime.to_date
            visits.first_line_drugs << drug.concept.shortname
            visits.first_line_drugs = visits.first_line_drugs.uniq rescue []
          elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_alt_line_regimen = treatment_encounter.encounter_datetime.to_date
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

    ans = ["Extrapulmonary tuberculosis (EPTB)","Pulmonary tuberculosis within the last 2 years","Pulmonary tuberculosis","Kaposis sarcoma"]
    staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all

    visits.ks = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[3])
    visits.tb_within_last_two_yrs = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[1])
    visits.eptb = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[0])
    visits.pulmonary_tb = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[2])

    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient_obj.id])

    visits.who_clinical_conditions = ""

    (hiv_staging.observations).collect do |obs|
      name = obs.to_s.split(':')[0].strip rescue nil
      next unless name == 'WHO STAGES CRITERIA PRESENT'
      condition = obs.to_s.split(':')[1].strip.humanize rescue nil
      visits.who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
    end rescue []

    # cd4_count_date cd4_count pregnant who_clinical_conditions

    visits.cd4_count_date = nil ; visits.cd4_count = nil ; visits.pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'CD4 COUNT DATETIME'
        visits.cd4_count_date = obs.value_datetime.to_date
      when 'CD4 COUNT'
        visits.cd4_count = obs.value_numeric
      when 'IS PATIENT PREGNANT?'
        visits.pregnant = obs.to_s.split(':')[1] rescue nil
      when 'LYMPHOCYTE COUNT'
        visits.tlc = obs.value_numeric
      when 'LYMPHOCYTE COUNT DATETIME'
        visits.tlc_date = obs.value_datetime.to_date
      end
    end rescue []

    visits.tb_status_at_initiation = (!visits.tb_status.nil? ? "Curr" :
          (!visits.tb_within_last_two_yrs.nil? ? (visits.tb_within_last_two_yrs.upcase == "YES" ? 
              "Last 2yrs" : "Never/ >2yrs") : "Never/ >2yrs"))

    art_initial = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("ART_INITIAL").id,patient_obj.id])

    (art_initial.observations).map do | obs |
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
  

  def visits(patient_obj,encounter_date = nil)
    patient_visits = {}
    yes = ConceptName.find_by_name("YES")
    if encounter_date.blank?
      observations = Observation.find(:all,:conditions =>["voided = 0 AND person_id = ?",patient_obj.patient_id],:order =>"obs_datetime")
    else
      observations = Observation.find(:all,
        :conditions =>["voided = 0 AND person_id = ? AND Date(obs_datetime) = ?",
        patient_obj.patient_id,encounter_date.to_date],:order =>"obs_datetime")
    end

    clinic_encounters = ["APPOINTMENT", "HEIGHT","WEIGHT","REGIMEN","TB STATUS","SYMPTOMS",
      "VISIT","BMI","PILLS BROUGHT",'ADHERENCE','NOTES','DRUGS GIVEN']
    clinic_encounters.map do |field|
      gave_hash = Hash.new(0) 
      observations.map do |obs|
         encounter_name = obs.encounter.name rescue []
         next if encounter_name.blank?
         next if encounter_name.match(/REGISTRATION/i)
         visit_date = obs.obs_datetime.to_date
         patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
         case field
          when 'APPOINTMENT'
            concept_name = obs.concept.fullname rescue nil
            next unless concept_name.upcase == 'APPOINTMENT DATE' 
            patient_visits[visit_date].appointment_date = obs.value_datetime
          when 'HEIGHT'
            concept_name = obs.concept.fullname rescue nil
            next unless concept_name.upcase == 'HEIGHT (CM)' 
            patient_visits[visit_date].height = obs.value_numeric
          when "WEIGHT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'WEIGHT (KG)' 
            patient_visits[visit_date].weight = obs.value_numeric
          when "BMI"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'BODY MASS INDEX, MEASURED' 
            patient_visits[visit_date].bmi = obs.value_numeric
          when "VISIT"
            concept_name = obs.concept.fullname.upcase rescue []
            next unless concept_name == 'RESPONSIBLE PERSON PRESENT' or concept_name == 'PATIENT PRESENT FOR CONSULTATION'
            patient_visits[visit_date].visit_by = '' if patient_visits[visit_date].visit_by.blank?
            patient_visits[visit_date].visit_by+= "P" if concept_name == 'PATIENT PRESENT FOR CONSULTATION' and obs.value_coded == yes.concept_id
            patient_visits[visit_date].visit_by+= "G" if concept_name == 'RESPONSIBLE PERSON PRESENT' and !obs.value_text.blank?
          when "TB STATUS"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'TB STATUS' 
            status = ConceptName.find(obs.value_coded_name_id).name.upcase rescue nil
            patient_visits[visit_date].tb_status = status
            patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
            patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
            patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
            patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
          when "DRUGS GIVEN"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'AMOUNT DISPENSED' 
            drug_name = Drug.find(obs.value_drug).name
            if drug_name.match(/Cotrimoxazole/i)
              patient_visits[visit_date].cpt += obs.value_numeric unless patient_visits[visit_date].cpt.blank?
              patient_visits[visit_date].cpt = obs.value_numeric if patient_visits[visit_date].cpt.blank?
            else
              patient_visits[visit_date].gave = [] if patient_visits[visit_date].gave.blank?
              patient_visits[visit_date].gave << [drug_name,obs.value_numeric]
            end
          when "REGIMEN"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'WHAT TYPE OF ANTIRETROVIRAL REGIMEN' 
            patient_visits[visit_date].reg =  Concept.find_by_concept_id(obs.value_coded).concept_names.typed("SHORT").first.name
          when "SYMPTOMS"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'SYMPTOM PRESENT' 
            symptoms = obs.to_s.split(':').map do | sy |
              sy.sub(concept_name,'').strip.capitalize 
            end rescue []
            patient_visits[visit_date].s_eff = symptoms.join("<br/>") unless symptoms.blank?
          when "PILLS BROUGHT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'AMOUNT OF DRUG BROUGHT TO CLINIC' 
            patient_visits[visit_date].pills = [] if patient_visits[visit_date].pills.blank?
            patient_visits[visit_date].pills << [Drug.find(obs.order.drug_order.drug_inventory_id).name,obs.value_numeric] rescue []
          when "ADHERENCE"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER' 
            next if obs.value_numeric.blank?
            patient_visits[visit_date].adherence = [] if patient_visits[visit_date].adherence.blank?
            patient_visits[visit_date].adherence << [Drug.find(obs.order.drug_order.drug_inventory_id).name,(obs.value_numeric.to_s + '%')]
          when "NOTES"
            concept_name = obs.concept.fullname.strip rescue []
            next unless concept_name == 'CLINICAL NOTES CONSTRUCT' || concept_name == 'Clinical notes construct'
            patient_visits[visit_date].notes+= '<br/>' + obs.value_text unless patient_visits[visit_date].notes.blank?
            patient_visits[visit_date].notes = obs.value_text if patient_visits[visit_date].notes.blank?
         end
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


    patient_states.each do |state| 
      visit_date = state.start_date.to_date
      patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
      patient_visits[visit_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
      patient_visits[visit_date].date_of_outcome = state.start_date
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
        patient_visits[encounter_date].date_of_outcome = state.start_date rescue nil
      end
    end


    patient_visits
  end  

  def mastercard_visit_label(patient,date = Date.today)
    visit = visits(patient,date)[date] rescue {}
    return if visit.blank? 
    visit_data = mastercard_visit_data(visit)

    arv_number = patient.arv_number || patient.national_id
    pill_count = visit.pills.collect{|c|c.join(",")}.join(' ') rescue nil

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient.name}(#{patient.person.sex.first})",25,60,0,3,1,1,false)
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
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    } rescue []
    label.print(1)
  end

  def adherence_to_show(adherence_data)
    #For now we will only show the adherence of the drug with the lowest/highest adherence %
    #i.e if a drug adherence is showing 86% and their is another drug with an adherence of 198%,then 
    #we will show the one with 198%.
    #in future we are planning to show all available drug adherences

    adherence_to_show = 0
    adherence_over_100 = 0
    adherence_below_100 = 0
    over_100_done = false
    below_100_done = false

    adherence_data.each{|drug,adh|
      next if adh.blank?
      drug_adherence = adh.to_i
      if drug_adherence <= 100
        adherence_below_100 = adh.to_i if adherence_below_100 == 0
        adherence_below_100 = adh.to_i if drug_adherence <= adherence_below_100
        below_100_done = true
      else
        adherence_over_100 = adh.to_i if adherence_over_100 == 0
        adherence_over_100 = adh.to_i if drug_adherence >= adherence_over_100
        over_100_done = true
      end

    }

    return if !over_100_done and !below_100_done
    over_100 = 0
    below_100 = 0
    over_100 = adherence_over_100 - 100 if over_100_done
    below_100 = 100 - adherence_below_100 if below_100_done

    return "#{adherence_over_100}%" if over_100 >= below_100 and over_100_done
    return "#{adherence_below_100}%"
  end

  def mastercard_visit_data(visit)
    return if visit.blank?
    data = {}

    data["outcome"] = visit.outcome rescue nil
    if visit.appointment_date and (data["outcome"].match(/ON ANTIRETROVIRALS/i) || data["outcome"].blank?)
      data["outcome"] = "Next: #{visit.appointment_date.strftime('%b %d %Y')}" 
    else
      data["outcome_date"] = "#{visit.date_of_outcome.to_date.strftime('%b %d %Y')}" if visit.date_of_outcome
    end

    count = 1
    visit.s_eff.split(",").each{|side_eff|
      data["side_eff#{count}"] = "25",side_eff[0..5]
      count+=1
    } if visit.s_eff

    count = 1
    (visit.gave).each do | drug, pills |
      string = "#{drug} (#{pills})"
      if string.length > 26
        line = string[0..25]
        line2 = string[26..-1] 
        data["arv_given#{count}"] = "255",line
        data["arv_given#{count+=1}"] = "255",line2
      else
        data["arv_given#{count}"] = "255",string
      end
      count+= 1
    end rescue []

    unless visit.cpt.blank?
      data["arv_given#{count}"] = "255","CPT (#{visit.cpt})" unless visit.cpt == 0
    end rescue []

    data
  end
  
  def seen_by(patient,date = Date.today)
    provider = patient.encounters.find_by_date(date).collect{|e| next unless e.name == 'ART VISIT' ; [e.name,e.creator]}.compact 
    provider_username = "#{'Seen by: ' + User.find(provider[0].last).username}" unless provider.blank?
    if provider_username.blank? 
      clinic_encounters = ["ART VISIT","HIV STAGING","ART ADHERENCE","TREATMENT",'DISPENSION','HIV RECEPTION']
      encounter_type_ids = EncounterType.find(:all,:conditions =>["name IN (?)",clinic_encounters]).collect{| e | e.id }
      encounter = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type In (?)",
                  patient.id,encounter_type_ids],:order => "encounter_datetime DESC")
      provider_username = "#{'Recorded by: ' + User.find(encounter.creator).username}" rescue nil
    end
    provider_username
  end
  
  private

end
