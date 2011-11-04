class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  require "fastercsv"

  helper :all
  helper_method :next_task
  filter_parameter_logging :password
  before_filter :login_required, :except => ['login', 'logout','demographics','create_remote', 'mastercard_printable']
  before_filter :location_required, :except => ['login', 'logout', 'location','demographics','create_remote', 'mastercard_printable']
  
  def rescue_action_in_public(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.info @message
    logger.info @backtrace
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

  def rescue_action(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.info @message
    logger.info @backtrace
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'production'

  def next_task(patient)
    session_date = session[:datetime].to_date rescue Date.today
    task = Task.next_task(Location.current_location, patient,session_date)
    begin
      return task.url if task.present? && task.url.present?
      return "/patients/show/#{patient.id}" 
    rescue
      return "/patients/show/#{patient.id}" 
    end
  end

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end
  
  def print_location_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    render :template => 'print/print_location', :layout => nil
  end

  def show_lab_results
    GlobalProperty.find_by_property('show.lab.results').property_value == "yes" rescue false
  end

  def use_filing_number
    GlobalProperty.find_by_property('use.filing.number').property_value == "yes" rescue false
  end    

 def generic_locations
    field_name = "name"

    sql = "SELECT *
          FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location'))
             ORDER BY name ASC"
      Location.find_by_sql(sql).collect{|name| name.send(field_name)} rescue []
  end

  def site_prefix
    site_prefix = GlobalProperty.find_by_property("site_prefix").property_value rescue false
    return site_prefix
  end

  def use_user_selected_activities
    GlobalProperty.find_by_property('use.user.selected.activities').property_value == "yes" rescue false
  end
  
  def tb_dot_sites_tag
    GlobalProperty.find_by_property('tb_dot_sites_tag').property_value rescue nil
  end

  def create_from_remote                                                        
    GlobalProperty.find_by_property('create.from.remote').property_value == "yes" rescue false
  end

  # Convert a list +Concept+s of +Regimen+s for the given +Patient+ <tt>age</tt>
  # into select options. See also +EncountersController#arv_regimen_answers+
  def regimen_options(regimen_concepts, age)
    options = regimen_concepts.map{ |r|
      [r.concept_id,

        (r.concept_names.typed("SHORT").first ||
        r.concept_names.typed("FULLY_SPECIFIED").first).name]
    }
	
    suffixed_options = options.collect{ |opt|
      opt_reg = Regimen.find(:all,
                             :select => 'regimen_index',
							 :order => 'regimen_index',
                             :conditions => ['concept_id = ?', opt[0]]
                            ).uniq.first
      if age >= 15
        suffix = "A"
      else
        suffix = "P"
      end

      #[opt[0], "#{opt_reg.regimen_index}#{suffix} - #{opt[1]}"]
		if opt_reg.regimen_index > -1
      		["#{opt_reg.regimen_index}#{suffix} - #{opt[1]}", opt[0], opt_reg.regimen_index.to_i]
		else
      		["#{opt[1]}", opt[0], opt_reg.regimen_index.to_i]
		end
    }.sort_by{|opt| opt[2]}

  end

  def remote_demographics(person_obj)
    demo = demographics(person_obj)

    demographics = {
                   "person" =>
                   {"attributes" => {
                      "occupation" => demo['person']['occupation'],
                      "cell_phone_number" => demo['person']['cell_phone_number']
                    } ,
                    "addresses" => 
                     { "address2"=> demo['person']['addresses']['location'],
                       "city_village" => demo['person']['addresses']['city_village'],
                       "address1"  => demo['person']['addresses']['address1'],
                       "county_district" => ""
                     },
                    "age_estimate" => person_obj.birthdate_estimated ,
                    "birth_month"=> person_obj.birthdate.month ,
                    "patient" =>{"identifiers"=>
                                {"National id"=> demo['person']['patient']['identifiers']['National id'] }
                               },
                    "gender" => person_obj.gender.first ,
                    "birth_day" => person_obj.birthdate.day ,
                    "date_changed" => demo['person']['date_changed'] ,
                    "names"=>
                      {
                        "family_name2" => demo['person']['names']['family_name2'],
                        "family_name" => demo['person']['names']['family_name'] ,
                        "given_name" => demo['person']['names']['given_name']
                      },
                    "birth_year" => person_obj.birthdate.year }
                    }
  end

  def demographics(person_obj)

    if person_obj.birthdate_estimated==1
      birth_day = "Unknown"
      if person_obj.birthdate.month == 7 and person_obj.birthdate.day == 1
        birth_month = "Unknown"
      else
        birth_month = person_obj.birthdate.month
      end
    else
      birth_month = person_obj.birthdate.month
      birth_day = person_obj.birthdate.day
    end

    demographics = {"person" => {
      "date_changed" => person_obj.date_changed.to_s,
      "gender" => person_obj.gender,
      "birth_year" => person_obj.birthdate.year,
      "birth_month" => birth_month,
      "birth_day" => birth_day,
      "names" => {
        "given_name" => person_obj.names[0].given_name,
        "family_name" => person_obj.names[0].family_name,
        "family_name2" => person_obj.names[0].family_name2
      },
      "addresses" => {
        "county_district" => person_obj.addresses[0].county_district,
        "city_village" => person_obj.addresses[0].city_village,
        "address1" => person_obj.addresses[0].address1,
        "address2" => person_obj.addresses[0].address2
      },
    "attributes" => {"occupation" => person_obj.get_attribute('Occupation'),
                     "cell_phone_number" => person_obj.get_attribute('Cell Phone Number')}}}
 
    if not person_obj.patient.patient_identifiers.blank? 
      demographics["person"]["patient"] = {"identifiers" => {}}
      person_obj.patient.patient_identifiers.each{|identifier|
        demographics["person"]["patient"]["identifiers"][identifier.type.name] = identifier.identifier
      }
    end

    return demographics
  end
  
  def current_treatment_encounter(date = Time.now(), provider = user_person_id)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = encounters.find(:first,:conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",date.to_date,type.id])
    encounter ||= encounters.create(:encounter_type => type.id,:encounter_datetime => date, :provider_id => provider)

  end
  
  def phone_numbers(person_obj)
    phone_numbers = {}

    phone_numbers['Cell phone number'] = person_obj.get_attribute('Cell phone number') rescue nil
    phone_numbers['Office phone number'] = person_obj.get_attribute('Office phone number') rescue nil
    phone_numbers['Home phone number'] = person_obj.get_attribute('Home phone number') rescue nil

    phone_numbers
  end

  def initial_encounter
    Encounter.find_by_sql("SELECT * FROM encounter ORDER BY encounter_datetime LIMIT 1").first
  end
  
  def create_remote_person(received_params)
    #raise known_demographics.to_yaml

    #Format params for BART
     new_params = received_params[:person]
     known_demographics = Hash.new()
     new_params['gender'] == 'F' ? new_params['gender'] = "Female" : new_params['gender'] = "Male"

       known_demographics = {
                  "occupation"=>"#{new_params[:occupation]}",
                   "patient_year"=>"#{new_params[:birth_year]}",
                   "patient"=>{
                    "gender"=>"#{new_params[:gender]}",
                    "birthplace"=>"#{new_params[:addresses][:address2]}",
                    "creator" => 1,
                    "changed_by" => 1
                    },
                   "p_address"=>{
                    "identifier"=>"#{new_params[:addresses][:state_province]}"},
                   "home_phone"=>{
                    "identifier"=>"#{new_params[:home_phone_number]}"},
                   "cell_phone"=>{
                    "identifier"=>"#{new_params[:cell_phone_number]}"},
                   "office_phone"=>{
                    "identifier"=>"#{new_params[:office_phone_number]}"},
                   "patient_id"=>"",
                   "patient_day"=>"#{new_params[:birth_day]}",
                   "patientaddress"=>{"city_village"=>"#{new_params[:addresses][:city_village]}"},
                   "patient_name"=>{
                    "family_name"=>"#{new_params[:names][:family_name]}",
                    "given_name"=>"#{new_params[:names][:given_name]}", "creator" => 1
                    },
                   "patient_month"=>"#{new_params[:birth_month]}",
                   "patient_age"=>{
                    "age_estimate"=>"#{new_params[:age_estimate]}"
                    },
                   "age"=>{
                    "identifier"=>""
                    },
                   "current_ta"=>{
                    "identifier"=>"#{new_params[:addresses][:county_district]}"}
                  }


    servers = GlobalProperty.find(:first, :conditions => {:property => "remote_servers.parent"}).property_value.split(/,/) rescue nil

    server_address_and_port = servers.to_s.split(':')

    server_address = server_address_and_port.first
    server_port = server_address_and_port.second

    return nil if servers.blank?

    wget_base_command = "wget --quiet --load-cookies=cookie.txt --quiet --cookies=on --keep-session-cookies --save-cookies=cookie.txt"

    login = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.username"}).property_value.split(/,/) rescue ''
    password = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.password"}).property_value.split(/,/) rescue ''
    location = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.location"}).property_value.split(/,/) rescue nil
    machine = GlobalProperty.find(:first, :conditions => {:property => "remote_machine.account_name"}).property_value.split(/,/) rescue ''
    post_data = known_demographics
    post_data["_method"]="put"

    local_demographic_lookup_steps = [ 
      "#{wget_base_command} -O /dev/null --post-data=\"login=#{login}&password=#{password}\" \"http://localhost/session\"",
      "#{wget_base_command} -O /dev/null --post-data=\"_method=put&location=#{location}\" \"http://localhost/session\"",
      "#{wget_base_command} -O - --post-data=\"#{post_data.to_param}\" \"http://localhost/patient/create_remote\""
    ]

    results = []
    servers.each{|server|
      command = "ssh #{machine}@#{server_address} '#{local_demographic_lookup_steps.join(";\n")}'"
      output = `#{command}`
      results.push output if output and output.match(/person/)
    }
    result = results.sort{|a,b|b.length <=> a.length}.first

    result ? person = JSON.parse(result) : nil
    begin
        person["person"]["addresses"]["address1"] = "#{new_params[:addresses][:address1]}"
        person["person"]["names"]["middle_name"] = "#{new_params[:names][:middle_name]}"
        person["person"]["occupation"] = known_demographics["occupation"]
        person["person"]["cell_phone_number"] = known_demographics["cell_phone"]["identifier"]
        person["person"]["home_phone_number"] = known_demographics["home_phone"]["identifier"]
        person["person"]["office_phone_number"] = known_demographics["office_phone"]["identifier"]
        person["person"]["attributes"].delete("occupation")
        person["person"]["attributes"].delete("cell_phone_number")
        person["person"]["attributes"].delete("home_phone_number")
        person["person"]["attributes"].delete("office_phone_number")
    rescue
    end   
    person
  end
  
  def find_remote_person(known_demographics)

    servers = GlobalProperty.find(:first, :conditions => {:property => "remote_servers.parent"}).property_value.split(/,/) rescue nil

    server_address_and_port = servers.to_s.split(':')

    server_address = server_address_and_port.first
    server_port = server_address_and_port.second

    return nil if servers.blank?

    wget_base_command = "wget --quiet --load-cookies=cookie.txt --quiet --cookies=on --keep-session-cookies --save-cookies=cookie.txt"
    # use ssh to establish a secure connection then query the localhost
    # use wget to login (using cookies and sessions) and set the location
    # then pull down the demographics
    # TODO fix login/pass and location with something better

    login = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.username"}).property_value.split(/,/) rescue ""
    password = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.password"}).property_value.split(/,/) rescue ""
    location = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.location"}).property_value.split(/,/) rescue nil
    machine = GlobalProperty.find(:first, :conditions => {:property => "remote_machine.account_name"}).property_value.split(/,/) rescue ''

    post_data = known_demographics
    post_data["_method"]="put"

    local_demographic_lookup_steps = [ 
      "#{wget_base_command} -O /dev/null --post-data=\"login=#{login}&password=#{password}\" \"http://localhost/session\"",
      "#{wget_base_command} -O /dev/null --post-data=\"_method=put&location=#{location}\" \"http://localhost/session\"",
      "#{wget_base_command} -O - --post-data=\"#{post_data.to_param}\" \"http://localhost/people/demographics\""
    ]

    results = []
    servers.each{|server|
      command = "ssh #{machine}@#{server_address} '#{local_demographic_lookup_steps.join(";\n")}'"
      output = `#{command}`
      results.push output if output and output.match /person/
    }
    # TODO need better logic here to select the best result or merge them
    # Currently returning the longest result - assuming that it has the most information
    # Can't return multiple results because there will be redundant data from sites
    result = results.sort{|a,b|b.length <=> a.length}.first
    result ? person = JSON.parse(result) : nil
    #Stupid hack to structure the hash for openmrs 1.7
    person["person"]["occupation"] = person["person"]["attributes"]["occupation"]
    person["person"]["cell_phone_number"] = person["person"]["attributes"]["cell_phone_number"]
    person["person"]["home_phone_number"] =  person["person"]["attributes"]["home_phone_number"]
    person["person"]["office_phone_number"] = person["person"]["attributes"]["office_phone_number"]
    person["person"]["attributes"].delete("occupation")
    person["person"]["attributes"].delete("cell_phone_number")
    person["person"]["attributes"].delete("home_phone_number")
    person["person"]["attributes"].delete("office_phone_number")

    person
  end
  
  def find_remote_person_by_identifier(identifier)
    known_demographics = {:person => {:patient => { :identifiers => {"National id" => identifier }}}}
    find_remote_person(known_demographics)
  end
  
  def find_person_by_demographics(person_demographics)
    national_id = person_demographics["person"]["patient"]["identifiers"]["National id"] rescue nil
    results = Person.search_by_identifier(national_id) unless national_id.nil?
    return results unless results.blank?

    gender = person_demographics["person"]["gender"] rescue nil
    given_name = person_demographics["person"]["names"]["given_name"] rescue nil
    family_name = person_demographics["person"]["names"]["family_name"] rescue nil

    search_params = {:gender => gender, :given_name => given_name, :family_name => family_name }

    results = Person.search(search_params)
  end

private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
  end
  
end
