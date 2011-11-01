class CohortToolController < ApplicationController

  def select
    @cohort_quarters  = [""]
    @report_type      = params[:report_type]
    @header 	        = params[:report_type] rescue ""
    @page_destination = ("/" + params[:dashboard].gsub("_", "/")) rescue ""

    if @report_type == "in_arv_number_range"
      @arv_number_start = params[:arv_number_start]
      @arv_number_end   = params[:arv_number_end]
    end

  start_date  = Encounter.initial_encounter.encounter_datetime rescue Date.today
  end_date    = Date.today

  @cohort_quarters  += Report.generate_cohort_quarters(start_date, end_date)
  end

  def reports
    session[:list_of_patients] = nil
    if params[:report]
      case  params[:report_type]
        when "visits_by_day"
          redirect_to :action   => "visits_by_day",
                      :name     => params[:report],
                      :pat_name => "Visits by day",
                      :quarter  => params[:report].gsub("_"," ")
        return

        when "non_eligible_patients_in_cohort"
          date = Report.generate_cohort_date_range(params[:report])

          redirect_to :action       => "non_eligible_patients_in_art",
                      :controller   => "report",
                      :start_date   => date.first.to_s,
                      :end_date     => date.last.to_s,
                      :id           => "start_reason_other",
                      :report_type  => "non_eligible patients in: #{params[:report]}"
        return

        when "out_of_range_arv_number"
          redirect_to :action           => "out_of_range_arv_number",
                      :arv_end_number   => params[:arv_end_number],
                      :arv_start_number => params[:arv_start_number],
                      :quarter          => params[:report].gsub("_"," "),
                      :report_type      => params[:report_type]
        return

        when "data_consistency_check"
          redirect_to :action       => "data_consistency_check",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "summary_of_records_that_were_updated"
          redirect_to :action   => "records_that_were_updated",
                      :quarter  => params[:report].gsub("_"," ")
        return

        when "adherence_histogram_for_all_patients_in_the_quarter"
          redirect_to :action   => "adherence",
                      :quarter  => params[:report].gsub("_"," ")
        return

        when "patients_with_adherence_greater_than_hundred"
          redirect_to :action  => "patients_with_adherence_greater_than_hundred",
                      :quater => params[:report].gsub("_"," ")
        return

        when "patients_with_multiple_start_reasons"
          redirect_to :action       => "patients_with_multiple_start_reasons",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "dispensations_without_prescriptions"
          redirect_to :action       => "dispensations_without_prescriptions",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "prescriptions_without_dispensations"
          redirect_to :action       => "prescriptions_without_dispensations",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "drug_stock_report"
          start_date  = "#{params[:start_year]}-#{params[:start_month]}-#{params[:start_day]}"
          end_date    = "#{params[:end_year]}-#{params[:end_month]}-#{params[:end_day]}"

          if end_date.to_date < start_date.to_date
            redirect_to :controller   => "cohort_tool",
                        :action       => "select",
                        :report_type  =>"drug_stock_report" and return
          end rescue nil

          redirect_to :controller => "drug",
                      :action     => "report",
                      :start_date => start_date,
                      :end_date   => end_date,
                      :quarter    => params[:report].gsub("_"," ")
        return
      end
    end
  end

  def records_that_were_updated
    @quarter    = params[:quarter]

    date_range  = Report.generate_cohort_date_range(@quarter)
    @start_date = date_range.first
    @end_date   = date_range.last

    @encounters = CohortTool.records_that_were_updated(@quarter)

    render :layout => false
  end

  def visits_by_day
    @quarter    = params[:quarter]

    date_range          = Report.generate_cohort_date_range(@quarter)
    @start_date         = date_range.first
    @end_date           = date_range.last
    visits              = Encounter.visits_by_day(@start_date.beginning_of_day, @end_date.end_of_day)
    @patients           = CohortTool.visiting_patients_by_day(visits)
    @visits_by_day      = CohortTool.visits_by_week(visits)
    @visits_by_week_day = CohortTool.visits_by_week_day(visits)

    render :layout => false
  end

  def prescriptions_without_dispensations
      include_url_params_for_back_button

      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      @report     = report_prescriptions_without_dispensations_data(start_date , end_date)

      render :layout => 'report'
  end
  
  def  dispensations_without_prescriptions
       include_url_params_for_back_button

      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      @report     = report_dispensations_without_prescriptions_data(start_date , end_date)

       render :layout => 'report'
  end
  
  def  patients_with_multiple_start_reasons
       include_url_params_for_back_button

      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      @report     = report_patients_with_multiple_start_reasons(start_date , end_date)

      render :layout => 'report'
  end
  
  def out_of_range_arv_number

      include_url_params_for_back_button

      date_range        = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      arv_number_range  = [params[:arv_start_number].to_i, params[:arv_end_number].to_i]

      @report = report_out_of_range_arv_numbers(arv_number_range, start_date, end_date)

      render :layout => 'report'
  end
  
  def data_consistency_check
      include_url_params_for_back_button
      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")

      @dead_patients_with_visits       = report_dead_with_visits(start_date, end_date)
      @males_allegedly_pregnant        = report_males_allegedly_pregnant(start_date, end_date)
      @move_from_second_line_to_first =  report_patients_who_moved_from_second_to_first_line_drugs(start_date, end_date)
      @patients_with_wrong_start_dates = report_with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)
      session[:data_consistency_check] = { :dead_patients_with_visits => @dead_patients_with_visits,
                                           :males_allegedly_pregnant  => @males_allegedly_pregnant,
                                           :patients_with_wrong_start_dates => @patients_with_wrong_start_dates,
                                           :move_from_second_line_to_first =>  @move_from_second_line_to_first
                                         }
      @checks = [['Dead patients with Visits', @dead_patients_with_visits.length],
                 ['Male patients with a pregnant observation', @males_allegedly_pregnant.length],
                 ['Patients who moved from 2nd to 1st line drugs', @move_from_second_line_to_first.length],
                 ['patients with start dates > first receive drug dates', @patients_with_wrong_start_dates.length]]
      render :layout => 'report'
  end
  
  def list
    @report = []
    include_url_params_for_back_button

    case params[:check_type]
       when 'Dead patients with Visits' then
            @report  =  session[:data_consistency_check][:dead_patients_with_visits]
       when 'Patients who moved from 2nd to 1st line drugs'then
             @report =  session[:data_consistency_check][:move_from_second_line_to_first]
       when 'Male patients with a pregnant observation' then
             @report =  session[:data_consistency_check][:males_allegedly_pregnant]
       when 'patients with start dates > first receive drug dates' then
             @report =  session[:data_consistency_check][:patients_with_wrong_start_dates]
       else

    end

    render :layout => 'report'
  end

  def include_url_params_for_back_button
       @report_quarter = params[:quarter]
       @report_type = params[:report_type]
  end
  
  def cohort
    @quater = params[:quater]
    start_date,end_date = Report.generate_cohort_date_range(@quater)
    cohort = Cohort.new(start_date,end_date)
    @cohort = cohort.report
    @survival_analysis = SurvivalAnalysis.report(cohort)
    render :layout => 'cohort'
  end

  def cohort_menu
  end

def adherence
    adherences = CohortTool.adherence(params[:quarter])
    @quater = params[:quarter]
    type = "patients_with_adherence_greater_than_hundred"
    @report_type = "Adherence Histogram for all patients"
    @adherence_summary = "&nbsp;&nbsp;<button onclick='adhSummary();'>Summary</button>" unless adherences.blank?
    @adherence_summary+="<input class='test_name' type=\"button\" onmousedown=\"document.location='/cohort_tool/reports?report=#{@quater}&report_type=#{type}';\" value=\"Over 100% Adherence\"/>"  unless adherences.blank?
    @adherence_summary_hash = Hash.new(0)
    adherences.each{|adherence,value|
      adh_value = value.to_i
      current_adh = adherence.to_i
      if current_adh <= 94
        @adherence_summary_hash["0 - 94"]+= adh_value
      elsif current_adh >= 95 and current_adh <= 100
        @adherence_summary_hash["95 - 100"]+= adh_value
      else current_adh > 100
        @adherence_summary_hash["> 100"]+= adh_value
      end
    }
    @adherence_summary_hash['missing'] = CohortTool.missing_adherence(@quater).length rescue 0
    @adherence_summary_hash.values.each{|n|@adherence_summary_hash["total"]+=n}

    data = ""
    adherences.each{|x,y|data+="#{x}:#{y}:"}
    @id = data[0..-2] || ''

    @results = @id
    @results = @results.split(':').enum_slice(2).map
    @results = @results.each {|result| result[0] = result[0]}.sort_by{|result| result[0]}
    @results.each{|result| @graph_max = result[1].to_f if result[1].to_f > (@graph_max || 0)}
    @graph_max ||= 0
    render :layout => false
  end

  def patients_with_adherence_greater_than_hundred

      min_range = params[:min_range]
      max_range = params[:max_range]
      missing_adherence = false
      missing_adherence = true if params[:show_missing_adherence] == "yes"
      session[:list_of_patients] = nil

      @patients = CohortTool.adherence_over_hundred(params[:quater],min_range,max_range,missing_adherence)

      @quater = params[:quater] + ": (#{@patients.length})" rescue  params[:quater]
      if missing_adherence
        @report_type = "Patient(s) with missing adherence"
      elsif max_range.blank? and min_range.blank?
        @report_type = "Patient(s) with adherence greater than 100%"
      else
        @report_type = "Patient(s) with adherence starting from  #{min_range}% to #{max_range}%"
      end
      render :layout => 'report'
      return
  end

  def report_patients_with_multiple_start_reasons(start_date , end_date)

    art_eligibility_id = ConceptName.find_by_name('REASON FOR ART ELIGIBILITY').concept_id    
    patients = Observation.find_by_sql(
                ["SELECT person_id, concept_id, date_created, obs_datetime, value_coded_name_id
                 FROM obs
                 WHERE (SELECT COUNT(*)
                        FROM obs observation
                        WHERE   observation.concept_id = ?
                                AND observation.person_id = obs.person_id) > 1                                
                                AND date_created >= ? AND date_created <= ?
                                AND obs.concept_id = ?
                                AND obs.voided = 0", art_eligibility_id, start_date, end_date, art_eligibility_id])

    patients_data = []

    patients.each do |reason|
      patient = Patient.find(reason[:person_id])
      patients_data << {'person_id' => patient.id,
                        'arv_number' => patient.arv_number,
                        'national_id' => patient.national_id,
                        'date_created' => reason[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
                        'start_reason' => ConceptName.find(reason[:value_coded_name_id]).name
                       }
    end
   patients_data
  end
  
  def report_out_of_range_arv_numbers(arv_number_range, start_date , end_date)
    arv_number_id             = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    arv_start_number          = arv_number_range.first
    arv_end_number            = arv_number_range.last

    out_of_range_arv_numbers  = PatientIdentifier.find_by_sql(["SELECT patient_id, identifier, date_created FROM patient_identifier
                                   WHERE identifier_type = ? AND REPLACE(identifier, 'MPC-ARV-', '') >= ?
                                   AND REPLACE(identifier, 'MPC-ARV-', '') <= ?
                                   AND voided = 0
                                   AND (NOT EXISTS(SELECT * FROM patient_identifier
                                   WHERE identifier_type = ? AND date_created >= ? AND date_created <= ?))",
                                   arv_number_id,  arv_start_number,  arv_end_number, arv_number_id, start_date, end_date])

    out_of_range_arv_numbers_data = []
    out_of_range_arv_numbers.each do |arv_num_data|
      patient     = Person.find(arv_num_data[:patient_id].to_i)
      national_id = patient.patient.national_id

      out_of_range_arv_numbers_data <<{'person_id' => patient.id,
                                       'arv_number' => arv_num_data[:identifier],
                                       'name' => patient.name,
                                       'national_id' => national_id,
                                       'gender' => patient.gender,
                                       'age' => patient.age,
                                       'birthdate' => patient.birthdate,
                                       'date_created' => arv_num_data[:date_created].strftime("%Y-%m-%d %H:%M:%S")
                                       }
    end
    out_of_range_arv_numbers_data
  end
  
  def report_dispensations_without_prescriptions_data(start_date , end_date)
    pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id

    missed_prescriptions_data = Observation.find(:all, :select =>  "person_id, value_drug, date_created",
                                              :conditions =>["order_id IS NULL
                                                AND date_created >= ? AND date_created <= ? AND
                                                    concept_id = ? AND voided = 0" ,start_date , end_date, pills_dispensed_id])
    dispensations_without_prescriptions = []

    missed_prescriptions_data.each do |dispensation|
        patient = Patient.find(dispensation[:person_id])
        drug_name    = Drug.find(dispensation[:value_drug]).name

        dispensations_without_prescriptions << { 'person_id' => patient.id,
                                              'arv_number' => patient.arv_number,
                                              'national_id' => patient.national_id,
                                              'date_created' => dispensation[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
                                              'drug_name' => drug_name
                                             }
    end

    dispensations_without_prescriptions
  end
  
  def report_prescriptions_without_dispensations_data(start_date , end_date)
    pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id

    missed_dispensations_data = Observation.find_by_sql(["SELECT order_id, patient_id, date_created from orders 
              WHERE NOT EXISTS (SELECT * FROM obs
               WHERE orders.order_id = obs.order_id AND obs.concept_id = ?)
                AND date_created >= ? AND date_created <= ? AND orders.voided = 0", pills_dispensed_id, start_date , end_date ])

    prescriptions_without_dispensations = []

    missed_dispensations_data.each do |prescription|
        patient      = Patient.find(prescription[:patient_id])
        drug_id      = DrugOrder.find(prescription[:order_id]).drug_inventory_id
        drug_name    = Drug.find(drug_id).name

        prescriptions_without_dispensations << {'person_id' => patient.id,
                                                'arv_number' => patient.arv_number,
                                                'national_id' => patient.national_id,
                                                'date_created' => prescription[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
                                                'drug_name' => drug_name
                                                }
    end
    prescriptions_without_dispensations
  end

  def report_dead_with_visits(start_date, end_date)
    patient_died_concept    = ConceptName.find_by_name('PATIENT DIED').concept_id

    all_dead_patients_with_visits = "SELECT * 
    FROM (SELECT observation.person_id AS patient_id, DATE(p.death_date) AS date_of_death, DATE(observation.date_created) AS date_started
          FROM person p right join obs observation ON p.person_id = observation.person_id
          WHERE p.dead = 1 AND DATE(p.death_date) < DATE(observation.date_created) AND observation.voided = 0
          ORDER BY observation.date_created ASC) AS dead_patients_visits
    WHERE DATE(date_of_death) >= DATE('#{start_date}') AND DATE(date_of_death) <= DATE('#{end_date}')
    GROUP BY patient_id"
    patients = Patient.find_by_sql([all_dead_patients_with_visits])
    
    patients_data  = []
    patients.each do |patient_data_row|
    person = Person.find(patient_data_row[:patient_id].to_i)
      patients_data <<{ 'person_id' => person.id,
                        'arv_number' => person.patient.arv_number,
                        'name' => person.name,
                        'national_id' => person.patient.national_id,
                        'gender' => person.gender,
                        'age' => person.age,
                        'birthdate' => person.birthdate,
                        'phone' => person.phone_numbers, 
                        'date_created' => patient_data_row[:date_started]
                       }
    end
    patients_data
  end
  
  def report_males_allegedly_pregnant(start_date, end_date)
    pregnant_patient_concept_id = ConceptName.find_by_name('IS PATIENT PREGNANT?').concept_id
    patients = PatientIdentifier.find_by_sql(["
                                   SELECT person.person_id,obs.obs_datetime
                                       FROM obs INNER JOIN person ON obs.person_id = person.person_id
                                           WHERE person.gender = 'M' AND
                                           obs.concept_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ? AND obs.voided = 0",
        pregnant_patient_concept_id, '2008-12-23 00:00:00', end_date])

        patients_data  = []
        patients.each do |patient_data_row|
          person = Person.find(patient_data_row[:person_id].to_i)

          patients_data <<{ 'person_id' => person.id,
                            'arv_number' => person.patient.arv_number,
                            'name' => person.name,
                            'national_id' => person.patient.national_id,
                            'gender' => person.gender,
                            'age' => person.age,
                            'birthdate' => person.birthdate,
                            'phone' => person.phone_numbers, 
                            'date_created' => patient_data_row[:obs_datetime]
                           }
        end
        patients_data
  end
  
  def report_patients_who_moved_from_second_to_first_line_drugs(start_date, end_date)
  
    first_line_regimen = "('D4T+3TC+NVP', 'd4T 3TC + d4T 3TC NVP')"
    second_line_regimen = "('AZT+3TC+NVP', 'D4T+3TC+EFV', 'AZT+3TC+EFV', 'TDF+3TC+EFV', 'TDF+3TC+NVP', 'TDF/3TC+LPV/r', 'AZT+3TC+LPV/R', 'ABC/3TC+LPV/r')"
    
    patients_who_moved_from_nd_to_st_line_drugs = "SELECT * FROM (
        SELECT patient_on_second_line_drugs.* , DATE(patient_on_first_line_drugs.date_created) AS date_started FROM (
        SELECT person_id, date_created
        FROM obs
        WHERE value_drug IN (
        SELECT drug_id 
        FROM drug 
        WHERE concept_id IN (SELECT concept_id FROM concept_name 
        WHERE name IN #{second_line_regimen}))
        ) AS patient_on_second_line_drugs inner join

        (SELECT person_id, date_created
        FROM obs
        WHERE value_drug IN (
        SELECT drug_id 
        FROM drug 
        WHERE concept_id IN (SELECT concept_id FROM concept_name 
        WHERE name IN #{first_line_regimen}))
        ) AS patient_on_first_line_drugs
        ON patient_on_first_line_drugs.person_id = patient_on_second_line_drugs.person_id
        WHERE DATE(patient_on_first_line_drugs.date_created) > DATE(patient_on_second_line_drugs.date_created) AND
              DATE(patient_on_first_line_drugs.date_created) >= DATE('#{start_date}') AND DATE(patient_on_first_line_drugs.date_created) <= DATE('#{end_date}')
        ORDER BY patient_on_first_line_drugs.date_created ASC) AS patients
        GROUP BY person_id"

    patients = Patient.find_by_sql([patients_who_moved_from_nd_to_st_line_drugs])
    
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:person_id].to_i)

      patients_data <<{ 'person_id' => person.id,
                        'arv_number' => person.patient.arv_number,
                        'name' => person.name,
                        'national_id' => person.patient.national_id,
                        'gender' => person.gender,
                        'age' => person.age,
                        'birthdate' => person.birthdate,
                        'phone' => person.phone_numbers, 
                        'date_created' => patient_data_row[:date_started]
                       }
    end
    patients_data
  end
  
  def report_with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)

    arv_drugs_concepts      = Drug.arv_drugs.inject([]) {|result, drug| result << drug.concept_id}
    on_arv_concept_id       = ConceptName.find_by_name('ON ANTIRETROVIRALS').concept_id
    hvi_program_id          = Program.find_by_name('HIV PROGRAM').program_id
    national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
    arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id

    patients_on_antiretrovirals_sql = "
         (SELECT p.patient_id, s.date_created as Date_Started_ARV
          FROM patient_program p INNER JOIN patient_state s
          ON  p.patient_program_id = s.patient_program_id
          WHERE s.state IN (SELECT program_workflow_state_id
                            FROM program_workflow_state g
                            WHERE g.concept_id = #{on_arv_concept_id})
                            AND p.program_id = #{hvi_program_id}
         ) patients_on_antiretrovirals"

    antiretrovirals_obs_sql = "
         (SELECT * FROM obs
          WHERE  value_drug IN (SELECT drug_id FROM drug
          WHERE concept_id IN ( #{arv_drugs_concepts.join(', ')} ) )
         ) antiretrovirals_obs"

    drug_start_dates_less_than_program_enrollment_dates_sql= "
      SELECT * FROM (
                  SELECT patients_on_antiretrovirals.patient_id, DATE(patients_on_antiretrovirals.date_started_ARV) AS date_started_ARV,
                         antiretrovirals_obs.obs_datetime, antiretrovirals_obs.value_drug
                  FROM #{patients_on_antiretrovirals_sql}, #{antiretrovirals_obs_sql}
                  WHERE patients_on_antiretrovirals.Date_Started_ARV > antiretrovirals_obs.obs_datetime
                        AND patients_on_antiretrovirals.patient_id = antiretrovirals_obs.person_id
                        AND patients_on_antiretrovirals.Date_Started_ARV >='#{start_date}' AND patients_on_antiretrovirals.Date_Started_ARV <= '#{end_date}'
                  ORDER BY patients_on_antiretrovirals.date_started_ARV ASC) AS patient_select
      GROUP BY patient_id"


    patients       = Patient.find_by_sql(drug_start_dates_less_than_program_enrollment_dates_sql)
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:patient_id])

      patients_data <<{ 'person_id' => person.id,
                        'arv_number' => person.patient.arv_number,
                        'name' => person.name,
                        'national_id' => person.patient.national_id,
                        'gender' => person.gender,
                        'age' => person.age,
                        'birthdate' => person.birthdate,
                        'phone' => person.phone_numbers, 
                        'date_created' => patient_data_row[:date_started_ARV]
                       }
    end
    patients_data
  end
  
end

