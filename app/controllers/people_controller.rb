class PeopleController < ApplicationController
  def index
    redirect_to "/clinic"
  end

  def new
  end
  
  def identifiers
  end

  def create_remote
    person_params = {"occupation"=> params[:occupation],
 "age_estimate"=> params['patient_age']['age_estimate'],
 "cell_phone_number"=> params['cell_phone']['identifier'],
 "birth_month"=> params[:patient_month],
 "addresses"=>{ "address2" => params['p_address']['identifier'],
 "city_village"=> params['patientaddress']['city_village'],
 "county_district"=> params[:birthplace] },
 "gender" => params['patient']['gender'],
 "birth_day" => params[:patient_day],
 "names"=> {"family_name2"=>"Unknown",
 "family_name"=> params['patient_name']['family_name'],
 "given_name"=> params['patient_name']['given_name'] },
 "birth_year"=> params[:patient_year] }

    #raise person_params.to_yaml
    if User.current_user.blank?
      User.current_user = User.find(1)
    end rescue []

    if Location.current_location.blank?
      Location.current_location = Location.find(GlobalProperty.find_by_property('current_health_center_id').property_value)
    end rescue []

    person = Person.create_from_form(person_params)
    if person
      patient = Patient.new()
      patient.patient_id = person.id
      patient.save
      patient.national_id_label 
    end
    #render :text => person.demographics.to_json
    render :text => person.remote_demographics.to_json
  end

  def demographics
    # Search by the demographics that were passed in and then return demographics
    people = Person.find_by_demographics(params)
    result = people.empty? ? {} : people.first.demographics
    render :text => result.to_json
  end
  
  def art_information
    national_id = params["person"]["patient"]["identifiers"]["National id"] rescue nil
    art_info = Patient.art_info_for_remote(national_id)
    render :text => art_info.to_json
  end
 
  def search
    found_person = nil
    if params[:identifier]
      local_results = Person.search_by_identifier(params[:identifier])
      if local_results.length > 1
        @people = Person.search(params)
      elsif local_results.length == 1
        found_person = local_results.first
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        found_person_data = Person.find_remote_by_identifier(params[:identifier])
        found_person =  Person.create_from_form(found_person_data) unless found_person_data.nil?
      end
      if found_person
        #redirect_to search_complete_url(found_person.id, params[:relation]) and return
        redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
      end
    end
    @people = Person.search(params)    
  end
  
  def confirm
    if request.post?
      redirect_to search_complete_url(params[:found_person_id], params[:relation]) and return
    end
    @found_person_id = params[:found_person_id] 
    @relation = params[:relation]
    @person = Person.find(@found_person_id) rescue nil
    render :layout => 'menu'
  end
 
  # This method is just to allow the select box to submit, we could probably do this better
  def select
    redirect_to search_complete_url(params[:person], params[:relation]) and return unless params[:person].blank? || params[:person] == '0'
    redirect_to :action => :new, :gender => params[:gender], :given_name => params[:given_name], :family_name => params[:family_name],
    :family_name2 => params[:family_name2], :address2 => params[:address2], :identifier => params[:identifier], :relation => params[:relation]
  end
 
  def create
    Person.session_datetime = session[:datetime].to_date rescue Date.today
    person = Person.create_from_form(params[:person])
    if params[:person][:patient]
      person.patient.national_id_label
      unless (params[:relation].blank?)
        redirect_to search_complete_url(person.id, params[:relation]) and return
      else
        if use_filing_number 
          person.patient.set_filing_number 
          archived_patient = person.patient.patient_to_be_archived
          message = Patient.printing_message(person.patient,archived_patient,creating_new_patient = true) 
          unless message.blank?
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}" , next_task(person.patient),message,true,person.id) 
          else
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient)) 
          end
        else
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
        end
      end  
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end

  def set_datetime
    if request.post?
      unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
        # set for 1 second after midnight to designate it as a retrospective date
        date_of_encounter = Time.mktime(params[:set_year].to_i,
                                        params[:set_month].to_i,                                
                                        params[:set_day].to_i,0,0,1) 
        session[:datetime] = date_of_encounter if date_of_encounter.to_date != Date.today 
      end
      unless params[:id].blank?
        redirect_to next_task(Patient.find(params[:id])) 
      else
        redirect_to :action => "index"
      end
    end
    @patient_id = params[:id]
  end

  def reset_datetime
    session[:datetime] = nil
    if params[:id].blank?
      redirect_to :action => "index" and return
    else
      redirect_to "/patients/show/#{params[:id]}" and return
    end
  end

  def find_by_arv_number
    if request.post?
      redirect_to :action => 'search' ,
        :identifier => "#{Location.current_arv_code} #{params[:arv_number]}" and return
    end
  end
  
private
  
  def search_complete_url(found_person_id, primary_person_id)
    unless (primary_person_id.blank?)
      # Notice this swaps them!
      new_relationship_url(:patient_id => primary_person_id, :relation => found_person_id)
    else
      url_for(:controller => :encounters, :action => :new, :patient_id => found_person_id)
    end
  end
end
 
