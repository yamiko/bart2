
def initialize
  @source_db= YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['bart2']["database"]
  @started_at = Time.now.strftime("%Y-%m-%d-%H%M%S")
end

def write_sql(a_hash,table)

    #open the necessary output file for writing
    if table == 'f1'
        $temp_outfile = File.open("./migration_output/flat_table_1-" + @started_at + ".sql", "w")
	initial_text = "INSERT INTO flat_table1 "
    elsif table == 'f2'
 	$temp_outfile = File.open("./migration_output/flat_table_2-" + @started_at + ".sql", "w") 
	initial_text = "INSERT INTO flat_table2 "
    elsif table == 'cft'
	$temp_outfile = File.open("./migration_output/cohort_flat_table-" + @started_at + ".sql", "w")
	initial_text = "INSERT INTO cohort_flat_table "
    else
	raise "Invalid table"
    end
    #initialize field and values variables
    fields = ""
    values = ""
   
    #create sql statement
    a_hash.each do |key,value|
	fields += fields.empty? ? "`#{key}`" : ", `#{key}`"
	values += values.empty? ? "`#{value}`" : ", `#{value}`"	
    end
    full_string = initial_text + "(" + fields + ")" + " VALUES (" + values + ");"
    
    #write to output file
    $temp_outfile << full_string

    #close the output file
    $temp_outfile.close
end

def get_all_patients
    patient_list = Patient.find_by_sql("SELECT patient_id FROM #{@source_db}.earliest_start_date").map(&:patient_id) 
    patient_list.each do |p|
	    get_patient_data(p)
    end
end

def get_patients_data(patient_id)
   #flat_table1 will contain hiv_staging, hiv clinic regitsrtaion observations
   #and patient demographics

   hiv_clinic_registration = []; hiv_staging = []; demographics = []
   initial_flat_table1_string = "INSERT INTO flat_table1 "

   #get patient demographics
   demographics = get_patient_demographics(patient_id)

   #hiv_clinic_registration observations
   hiv_clinic_reg_obs = Encounter.find(:first,
                                       :conditions => ['patient_id = ?
                                                        AND encounter_type = 9',
                                                        patient_id],
                                       :order => 'encounter_datetime DESC').observations
   if hiv_clinic_reg_obs
    hiv_clinic_registration = process_hiv_clinic_registration_encounter(hiv_clinic_reg_obs)
   end

   #hiv_staging observations
   hiv_staging_obs = Encounter.find(:first,
                                    :conditions => ['patient_id = ?
                                                     AND encounter_type = 52',
                                                     patient_id],
                                    :order => 'encounter_datetime DESC').observations

  if hiv_staging_obs
    hiv_staging = process_hiv_staging_encounter(hiv_staging_obs)
  end

  #check if any of the strings are empty
  demographics = get_patient_demographics(patient_id, 1) if demographics.empty?
  hiv_staging = process_hiv_staging_encounter(hiv_staging_obs, 1) if hiv_staging.empty?
  hiv_clinic_registration = process_hiv_clinic_registration_encounter(hiv_clinic_reg_obs, 1) if hiv_clinic_registration.empty?

  #write sql statement

  sql_statement = initial_flat_table1_string + "(" + demographics[0] + hiv_clinic_registration[0] + hiv_staging[0] ")" + \
		 " VALUES (" + demographics + hiv_clinic_registration[1] + hiv_staging[1] + ");"

  $temp_outfile = File.open("./migration_output/flat_table_1-" + @started_at + ".sql", "w")
  $temp_outfile << sql_statement
  $temp_outfile.close

  visits = Encounter.find_by_sql("SELECT date(encounter_datetime) AS visit_date FROM #{@source_db}.encounter
				WHERE patient_id = #{patient_id} AND voided = 0  
				group by date(encounter_datetime)").map(&:visit_date)

  #list of encounters for bart2
  #vitals => 6, appointment => 7, treatment => 25, hiv clinic consultation => 53, hiv_reception => 51
  initial_string = "INSERT INTO flat_table2 "

  visits.each do |visit|
	# arrays of [fields, values]
	vitals = []
	appointment = []
	hiv_clinic_consultation = []
	hiv_reception = []
  patient_orders = []

  orders = Order.find_by_sql("SELECT o.patient_id, o.order_id, o.encounter_id,
                                         o.start_date, o.auto_expire_date, d.quantity,
                                         d.drug_inventory_id, d.dose, d.frequency,
                                         o.concept_id, d.equivalent_daily_dose
                              FROM orders o
                                INNER JOIN drug_order d ON d.order_id = o.order_id
                              WHERE o.start_date = '#{visit}'
                              AND o.patient_id = #{patient_id} ")

  if orders
    patient_orders = process_patient_orders(orders, 1) if patient_orders.empty?
  end

	encounters = Encounter.find(:all,
			:include => [:observations],
			:order => "encounter_datetime ASC"
			:conditions => ['voided = 0 AND patient_id = ? AND date(encounter_datetime) = ?', patient_id, visit])
	
	encounters.each do |enc|
		if enc.encounter_type == 6 #vitals
			vitals = process_vitals_encounter(encounter)
		elsif enc.encounter_type == 51#HIV Reception
			hiv_reception = process_hiv_reception_encounter(encounter)
		elsif enc.encounter_type == 53 #HIV Clinic Consultation
			hiv_clinic_consultation = process_hiv_clinic_consultation_encounter(encounter)
		elsif

		end
	end

   #write sql statement
    sql_statement = initial_string + "(" + vitals[0] + appointment[0] + hcc[0] + hiv_reception[0] + patient_orders[0] + ")" + \
		 " VALUES (" + vitals[1] + appointment[1] + hcc[1] + hiv_reception[1] + patient_orders[1] + ");"
	
    $temp_outfile = File.open("./migration_output/flat_table_2-" + @started_at + ".sql", "w")
    $temp_outfile << sql_statement
    $temp_outfile.close
	
   end
end

def get_patient_demographics(patient_id)
  #get all patient visits
  pat = Patient.find(patient_id)
  patient_obj = PatientService.get_patient(pat.person) #rescue nil

  earliest_start_date = PatientProgram.find_by_sql("SELECT *
                                           FROM earliest_start_date
                                           WHERE patient_id = #{patient_id}").map(&:earliest_start_date).first

  a_hash[:given_name] = patient_obj.first_name
  a_hash[:middle_name] = patient_obj.last_name
  a_hash[:family_name] = patient_obj.last_name
  a_hash[:gender] = patient_obj.sex
  a_hash[:dob] = patient_obj.birth_date
  a_hash[:dob_estimated] = patient_obj.birthdate_estimated
  a_hash[:ta] = patient_obj.traditional_authority
  a_hash[:current_address] = patient_obj.current_residence
  a_hash[:home_district] = patient_obj.home_district
  a_hash[:landmark] = patient_obj.landmark
  a_hash[:cellphone_number] = patient_obj.cell_phone_number
  a_hash[:home_phone_number] = patient_obj.home_phone_number
  a_hash[:office_phone_number] = patient_obj.office_phone_number
  a_hash[:occupation] = patient_obj.occupation
  a_hash[:nat_id] = patient_obj.national_id
  a_hash[:arv_number]  = patient_obj.arv_number
  a_hash[:pre_art_number] = patient_obj.pre_art_number
  a_hash[:tb_number]  = PatientService.get_patient_identifier(pat, 'District TB Number')
  a_hash[:legacy_id]  = patient_obj.occupation
  a_hash[:legacy_id2]  = patient_obj.occupation
  a_hash[:legacy_id3]  = patient_obj.occupation
  a_hash[:new_nat_id]  = patient_obj.occupation
  a_hash[:prev_art_number]  = PatientService.get_patient_identifier(pat, 'z_deprecated Pre ART Number (Old format)')
  a_hash[:filing_number]  = patient_obj.filing_number
  a_hash[:archived_filing_number]  = patient_obj.archived_filing_number
  a_hash[:earliest_start_date]  = earliest_start_date
end

def process_vitals_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash = {  :height => 0,
		:height_enc_id => 0,
                :weight => 0,
		:weight_enc_id => 0,
                :temperature => 0,
		:temperature_enc_id => 0,
                :bmi => 0,
		:bmi_enc_id => 0,
                :systolic_blood_pressure => 0,
		:systolic_blood_pressure_enc_id => 0,
                :diastolic_blood_pressure => 0,
		:diastolic_blood_pressure_enc_id => 0
                :weight_for_height => 0,
		:weight_for_height_enc_id => 0,
                :weight_for_age => 0,
		:weight_for_age_enc_id => 0,
                :height_for_age => 0,
		:height_for_age_enc_id => 0
                }

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
        if obs.concept_id == 5089 #weight
                a_hash[:weight] = obs.value_numeric
		a_hash[:weight_enc_id] = encounter.encounter_id
        elsif obs.concept_id == 5090 #height
                a_hash[:height] = obs.value_numeric
		a_hash[:height_enc_id] = encounter.encounter_id
        elsif obs.concept_id == 5088 #temperature
                a_hash[:temperature] = obs.value_numeric
		a_hash[:temperature_enc_id] = encounter.encounter_id
        elsif obs.concept_id == 2137 #bmi
                a_hash[:bmi] = obs.value_numeric
		a_hash[:bmi_enc_id] = encounter.encounter_id
        elsif obs.concept_id == 5085 #systolic blood pressure
                a_hash[:systolic_blood_pressure] = obs.value_numeric
		a_hash[:systolic_blood_pressure_enc_id] = encounter.encounter_id
        elsif obs.concept_id == 5086 #diastolic blood pressure
                a_hash[:diastolic_blood_pressure] = obs.value_numeric
		a_hash[:diastolic_blood_pressure_enc_id] = encounter.encounter_id
        elsif obs.concept_id == 1822 #weight for height
                a_hash[:weight_for_height] = obs.value_numeric
		a_hash[:weight_for_height_enc_id] = encounter.encounter_id
        elsif obs.concept_id == 6396 #weight for age
                a_hash[:weight_for_age] = obs.value_numeric
		a_hash[:weight_for_age_enc_id] = encounter.encounter_id 
        elsif obs.concept_id == 6397 #height_for_age 
                a_hash[:height_for_age] = obs.value_numeric
		a_hash[:height_for_age_enc_id] = encounter.encounter_id
        end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_reception_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =	  {:patient_present_no => 'NULL',
                   :patient_present_yes => 'NULL',
                   :patient_present_yes_enc_id => 'NULL',
                   :patient_present_no_enc_id => 'NULL',
                   :guardian_present_yes => 'NULL',
                   :guardian_present_no => 'NULL',
                   :guardian_present_yes_enc_id => 'NULL',
                   :guardian_present_no_enc_id => 'NULL'
                }

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id == 2122 #Guardian Present
		if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
			a_hash[:guardian_present_yes] = 'Yes'
			a_hash[:guardian_present_yes_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
			a_hash[:guardian_present_no] = 'No'
			a_hash[:guardian_present_no_enc_id] = encounter.encounter_id
		end		
        elsif obs.concept_id == 1805 #Patient Present
                if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
                        a_hash[:patient_present_yes] = 'Yes'           
                        a_hash[:patient_present_yes_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
                        a_hash[:patient_present_no] = 'No'             
                        a_hash[:patient_present_no_enc_id] = encounter.encounter_id
                end	
        end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_clinic_consultation_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =   {:pregnant_yes => 'NULL',
		:pregnant_yes_enc_id => 'NULL',
		:pregnant_no => 'NULL',
		:pregnant_no_enc_id => 'NULL',
		:breastfeeding_yes => 'NULL'
                :breastfeeding_yes_enc_id => 'NULL',
		:breastfeeding_no => 'NULL',
		:breastfeeding_no_enc_id => 'NULL',
                :currently_using_family_planning_method_yes => 'NULL',
                :currently_using_family_planning_method_yes_enc_id => 'NULL',
                :currently_using_family_planning_method_no => 'NULL',
                :currently_using_family_planning_method_no_enc_id => 'NULL',
		:family_planning_method_oral_contraceptive_pills => 'NULL',
		:family_planning_method_oral_contraceptive_pills_enc_id => 'NULL',
		:family_planning_method_depo_provera => 'NULL',
		:family_planning_method_depo_provera_enc_id => 'NULL',
		:family_planning_method_intrauterine_contraception => 'NULL',
		:family_planning_method_intrauterine_contraception_enc_id => 'NULL',
		:family_planning_method_contraceptive_implant => 'NULL',
		:family_planning_method_contraceptive_implant_enc_id => 'NULL',
		:family_planning_method_male_condoms => 'NULL',
		:family_planning_method_male_condoms_enc_id => 'NULL',
		:family_planning_method_female_condoms => 'NULL',
		:family_planning_method_female_condoms_enc_id => 'NULL',
		:family_planning_method__rythm_method => 'NULL',
		:family_planning_method__rythm_method_enc_id => 'NULL',
		:family_planning_method_withdrawal => 'NULL',
		:family_planning_method_withdrawal_enc_id => 'NULL',
		:family_planning_method_abstinence => 'NULL',
		:family_planning_method_abstinence_enc_id => 'NULL',
		:family_planning_method_tubal_ligation => 'NULL',
		:family_planning_method_tubal_ligation_enc_id => 'NULL',
		:family_planning_method_emergency__contraception => 'NULL',
		:family_planning_method_emergency__contraception_enc_id => 'NULL',
		:family_planning_method_vasectomy => 'NULL',
		:family_planning_method_vasectomy_enc_id => 'NULL',
		:symptom_present_lipodystrophy => 'NULL',        
		:symptom_present_lipodystrophy_enc_id => 'NULL',        
		:symptom_present_anemia => 'NULL',        
		:symptom_present_anemia_enc_id => 'NULL',        
		:symptom_present_jaundice => 'NULL',        
		:symptom_present_jaundice_enc_id => 'NULL',        
		:symptom_present_lactic_acidosis => 'NULL',        
		:symptom_present_lactic_acidosis_enc_id => 'NULL',        
		:symptom_present_fever => 'NULL',        
		:symptom_present_fever_enc_id => 'NULL',        
		:symptom_present_skin_rash => 'NULL',        
		:symptom_present_skin_rash_enc_id => 'NULL',        
		:symptom_present_abdominal_pain => 'NULL',        
		:symptom_present_abdominal_pain_enc_id => 'NULL',        
		:symptom_present_anorexia => 'NULL',        
		:symptom_present_anorexia_enc_id => 'NULL',        
		:symptom_present_cough => 'NULL',        
		:symptom_present_cough_enc_id => 'NULL',        
		:symptom_present_diarrhea => 'NULL',        
		:symptom_present_diarrhea_enc_id => 'NULL',        
		:symptom_present_hepatitis => 'NULL',        
		:symptom_present_hepatitis_enc_id => 'NULL',        
		:symptom_present_leg_pain_numbness => 'NULL',        
		:symptom_present_leg_pain_numbness_enc_id => 'NULL',        
		:symptom_present_peripheral_neuropathy => 'NULL',        
		:symptom_present_peripheral_neuropathy_enc_id => 'NULL',        
		:symptom_present_vomiting => 'NULL',        
		:symptom_present_vomiting_enc_id => 'NULL',        
		:symptom_present_other_symptom => 'NULL',        
		:symptom_present_other_symptom_enc_id => 'NULL',        
		:side_effects_peripheral_neuropathy => 'NULL',
		:side_effects_peripheral_neuropathy_enc_id => 'NULL',
		:side_effects_hepatitis => 'NULL',
		:side_effects_hepatitis_enc_id => 'NULL',
		:side_effects_skin_rash => 'NULL',
		:side_effects_skin_rash_enc_id => 'NULL',
		:side_effects_lipodystrophy => 'NULL',
		:side_effects_lipodystrophy_enc_id => 'NULL',
		:side_effects_other => 'NULL',
		:side_effects_other_enc_id => 'NULL',
		:drug_induced_abdominal_pain => 'NULL',
		:drug_induced_abdominal_pain_enc_id => 'NULL',
		:drug_induced_anorexia => 'NULL',
		:drug_induced_anorexia_enc_id => 'NULL',
		:drug_induced_diarrhea => 'NULL',
		:drug_induced_diarrhea_enc_id => 'NULL',
		:drug_induced_jaundice => 'NULL',
		:drug_induced_jaundice_enc_id => 'NULL',
		:drug_induced_leg_pain_numbness => 'NULL',
		:drug_induced_leg_pain_numbness_enc_id => 'NULL',
		:drug_induced_vomiting => 'NULL',
		:drug_induced_vomiting_enc_id => 'NULL',
		:drug_induced_peripheral_neuropathy => 'NULL',
		:drug_induced_peripheral_neuropathy_enc_id => 'NULL',
		:drug_induced_hepatitis => 'NULL',
		:drug_induced_hepatitis_enc_id => 'NULL',
		:drug_induced_anemia => 'NULL',
		:drug_induced_anemia_enc_id => 'NULL',
		:drug_induced_lactic_acidosis => 'NULL',
		:drug_induced_lactic_acidosis_enc_id => 'NULL',
		:drug_induced_lipodystrophy => 'NULL',
		:drug_induced_lipodystrophy_enc_id => 'NULL',
		:drug_induced_skin_rash => 'NULL',
		:drug_induced_skin_rash_enc_id => 'NULL',
		:drug_induced_other_symptom => 'NULL',
		:drug_induced_other_symptom_enc_id => 'NULL',
		:drug_induced_fever => 'NULL',
		:drug_induced_fever_enc_id => 'NULL',
		:drug_induced_cough => 'NULL',
		:drug_induced_cough_enc_id => 'NULL',
		:tb_status_tb_not_suspected => 'NULL',
                :tb_status_tb_not_suspected_enc_id => 'NULL',
                :tb_status_tbsuspected => 'NULL',
                :tb_status_tb_suspected_enc_id => 'NULL',
                :tb_status_confirmed_tb_not_on_treatment => 'NULL',
                :tb_status_confirmed_tb_not_on_treatment_enc_id => 'NULL',
                :tb_status_confirmed_tb_on_treatment => 'NULL',
                :tb_status_confirmed_tb_on_treatment_enc_id => 'NULL',
                :tb_status_unknown => 'NULL',
                :tb_status_unknown_enc_id => 'NULL',
                :prescribe_arvs_yes => 'NULL',
                :prescribe_arvs_yes_enc_id => 'NULL',
                :prescribe_arvs_no => 'NULL',
                :prescribe_arvs_no_enc_id => 'NULL',
                :routine_tb_screening_fever => 'NULL',
                :routine_tb_screening_fever_enc_id => 'NULL',
                :routine_tb_screening_night_sweats => 'NULL',
                :routine_tb_screening_night_sweats_enc_id => 'NULL',
                :routine_tb_screening_cough_of_any_duration => 'NULL',
                :routine_tb_screening_cough_of_any_duration_enc_id => 'NULL',
                :routine_tb_screening_weight_loss_failure => 'NULL',
                :routine_tb_screening_weight_loss_failure_enc_id => 'NULL',
                :allergic_to_surphur_yes => 'NULL',
                :allergic_to_surphur_yes_enc_id => 'NULL',
                :allergic_to_surphur_no => 'NULL',
                :allergic_to_surphur_no_enc => 'NULL'
                }

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
        if obs.concept_id == 6131 #Patient Pregnant
                if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
                        a_hash[:patient_pregnant_yes] = 'Yes'
                        a_hash[:patient_pregnant_yes_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
                        a_hash[:patient_pregnant_no] = 'No'
                        a_hash[:patient_pregnant_no_enc_id] = encounter.encounter_id
                end
        elsif obs.concept_id == 7965 #breastfeeding
                if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
                        a_hash[:breastfeeding_yes] = 'Yes'
                        a_hash[:breastfeeding_yes_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
                        a_hash[:breastfeeding_no] = 'No'
                        a_hash[:breastfeeding_no_enc_id] = encounter.encounter_id
                end
	elsif obs.concept_id == 7459 #tb status
		if obs.value_coded == 7454 && obs.value_coded_name_id == 10270
			a_hash[:tb_status_tb_not_suspected] = 'Yes'
			a_hash[:tb_status_tb_not_suspected_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 7455 && obs.value_coded_name_id == 10273
			a_hash[:tb_status_tbsuspected] = 'Yes'
                        a_hash[:tb_status_tb_suspected_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 7456 && obs.value_coded_name_id == 10274
			a_hash[:tb_status_confirmed_tb_not_on_treatment] = 'Yes'
                        a_hash[:tb_status_confirmed_tb_not_on_treatment_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 7458 && obs.value_coded_name_id == 10279
			a_hash[:tb_status_confirmed_tb_on_treatment] = 'Yes'
                        a_hash[:tb_status_confirmed_tb_on_treatment_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 1067 && obs.value_coded_name_id == 1104
			a_hash[:tb_status_unknown] = 'Yes'
                        a_hash[:tb_status_unknown_enc_id] = encounter.encounter_id
		end
        elsif obs.concept_id == 1717 #using family planning methods
                if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
                        a_hash[:currently_using_family_planning_method_yes] = 'Yes'
                        a_hash[:currently_using_family_planning_method_yes_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
                        a_hash[:currently_using_family_planning_method_no] = 'No'
                        a_hash[:currently_using_family_planning_method_no_enc_id] = encounter.encounter_id
                end
        elsif obs.concept_id == 374 #family planning method
                if obs.value_coded == 780 && obs.value_coded_name_id == 10736
                        a_hash[:family_planning_method_oral_contraceptive_pills] = 'Yes'
                        a_hash[:family_planning_method_oral_contraceptive_pills_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 907 && obs.value_coded_name_id == 931
                        a_hash[:family_planning_method_depo_provera] = 'Yes'
                        a_hash[:family_planning_method_depo_provera_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 5275 && obs.value_coded_name_id == 10737
                        a_hash[:family_planning_method_intrauterine_contraception] = 'Yes'
                        a_hash[:family_planning_method_intrauterine_contraception_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 7857 && obs.value_coded_name_id == 10738
                        a_hash[:family_planning_method_contraceptive_implant] = 'Yes'
                        a_hash[:family_planning_method_contraceptive_implant_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 7858 && obs.value_coded_name_id == 10739
                        a_hash[:family_planning_method_male_condoms] = 'Yes'
                        a_hash[:family_planning_method_male_condoms_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 7859 && obs.value_coded_name_id == 10740
                        a_hash[:family_planning_method_female_condoms] = 'Yes'
                        a_hash[:family_planning_method_female_condoms_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 7860 && obs.value_coded_name_id == 10741
                        a_hash[:family_planning_method__rythm_method] = 'Yes'
                        a_hash[:family_planning_method__rythm_method_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 7861 && obs.value_coded_name_id == 10743
                        a_hash[:family_planning_method_withdrawal] = 'Yes'
                        a_hash[:family_planning_method_withdrawal_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1720 && obs.value_coded_name_id == 1876
                        a_hash[:family_planning_method_abstinence] = 'Yes'
                        a_hash[:family_planning_method_abstinence_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1719 && obs.value_coded_name_id == 1874
                        a_hash[:family_planning_method_tubal_ligation] = 'Yes'
                        a_hash[:family_planning_method_tubal_ligation_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1721 && obs.value_coded_name_id == 1877
                        a_hash[:family_planning_method_vasectomy] = 'Yes'
                        a_hash[:family_planning_method_vasectomy_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 7862 && obs.value_coded_name_id == 10744
                        a_hash[:family_planning_method_emergency__contraception] = 'Yes'
                        a_hash[:family_planning_method_emergency__contraception_enc_id] = encounter.encounter_id
                end
	elsif obs.concept_id == 1293 #symptoms present
                if obs.value_coded == 2148 && obs.value_coded_name_id == 2325
                        a_hash[:symptom_present_lipodystrophy] = 'Yes'
                        a_hash[:symptom_present_lipodystrophy_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 3 && obs.value_coded_name_id == 3
                        a_hash[:symptom_present_anemia] = 'Yes'
                        a_hash[:symptom_present_anemia_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 215 && obs.value_coded_name_id == 226
                        a_hash[:symptom_present_jaundice] = 'Yes'
                        a_hash[:symptom_present_jaundice_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1458 && obs.value_coded_name_id == 1576
                        a_hash[:symptom_present_lactic_acidosis] = 'Yes'
                        a_hash[:symptom_present_lactic_acidosis_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 5945 && obs.value_coded_name_id == 4315
                        a_hash[:symptom_present_fever] = 'Yes'
                        a_hash[:symptom_present_fever_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 512 && obs.value_coded_name_id == 524
                        a_hash[:symptom_present_skin_rash] = 'Yes'
                        a_hash[:symptom_present_skin_rash_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 151 && obs.value_coded_name_id == 156
                        a_hash[:symptom_present_abdominal_pain] = 'Yes'
                        a_hash[:symptom_present_abdominal_pain_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 868 && obs.value_coded_name_id == 888
                        a_hash[:symptom_present_anorexia] = 'Yes'
                        a_hash[:symptom_present_anorexia_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 107 && obs.value_coded_name_id == 110
                        a_hash[:symptom_present_cough] = 'Yes'
                        a_hash[:symptom_present_cough_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 16 && obs.value_coded_name_id == 17
			a_hash[:symptom_present_diarrhea] = 'Yes'
                        a_hash[:symptom_present_diarrhea_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 7952 && obs.value_coded_name_id == 10894
			a_hash[:symptom_present_leg_pain_numbness] = 'Yes'
                        a_hash[:symptom_present_leg_pain_numbness_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 821 && obs.value_coded_name_id == 838
			a_hash[:symptom_present_peripheral_neuropathy = 'Yes'
                        a_hash[:symptom_present_peripheral_neuropathy_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 5980 && obs.value_coded_name_id == 4355
			a_hash[:symptom_present_vomiting] = 'Yes'
                        a_hash[:symptom_present_vomiting_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 6779 && obs.value_coded_name_id == 4355
			a_hash[:symptom_present_other_symptom] = 'Yes'
                        a_hash[:symptom_present_other_symptom_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 29 && obs.value_coded_name_id == 30
			a_hash[:symptom_present_hepatitis] = 'Yes'
                        a_hash[:symptom_present_hepatitis_enc_id] = encounter.encounter_id
		end
        elsif obs.concept_id == 8012 #allergic to sulpher
                if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
                        a_hash[:allergic_to_sulpger_yes] = 'Yes'
                        a_hash[:allergic_to_sulpher_yes_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
                        a_hash[:allergic_to_sulpher_no] = 'No'
                        a_hash[:allergic_to_sulpher_no_enc_id] = encounter.encounter_id
                end
        elsif obs.concept_id == 7874 #prescribe drugs
                if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
                        a_hash[:prescribe_arvs_yes] = 'Yes'
                        a_hash[:prescribe_arvs_yes_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
                        a_hash[:prescribe_arvs_no] = 'No'
                        a_hash[:prescribe_arvs_no_enc_id] = encounter.encounter_id
                end
	elsif obs.concept_id == 8259 #routine tb screening
		if obs.value_coded == 5945 && obs.value_coded_name_id == 4315
			a_hash[:routine_tb_screening_fever] = 'Yes'
			a_hash[:routing_tb_screening_fever_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 6029 && obs.value_coded_name_id == 4407
			a_hash[:routine_tb_screening_night_sweats] = 'Yes'
                        a_hash[:routine_tb_screening_night_sweats_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 8261 && obs.value_coded_name_id == 11335
			a_hash[:routine_tb_screening_cough_of_any_duration] = 'Yes'
                        a_hash[:routine_tb_screening_cough_of_any_duration_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 8260 && obs.value_coded_name_id == 11333
			a_hash[:routine_tb_screening_weight_loss_failure] = 'Yes'
                        a_hash[:routine_tb_screening_weight_loss_failure_enc_id] = encounter.encounter_id
		end
       	elsif obs.concept_id == 2146 #side effects
		if obs.value_coded == 821 && obs.value_coded_name_id == 838
			a_hash[:side_effects_peripheral_neuropathy] = 'Yes'
			a_hash[:side_effects_peripheral_neuropathy_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 29 && obs.value_coded_name_id == 30
			a_hash[:side_effects_hepatitis] = 'Yes'
                        a_hash[:side_effects_hepatitis_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 512 && obs.value_coded_name_id == 524
			a_hash[:side_effects_skin_rash] = 'Yes'
                        a_hash[:side_effects_skin_rash_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 2148 && obs.value_coded_name_id == 2325
			a_hash[:side_effects_lipodystrophy] = 'Yes'
                        a_hash[:side_effects_lipodystrophy_enc_id] = encounter.encounter_id
		elsif obs.value_coded == 6408 && obs.value_coded_name_id == 8873
			a_hash[:side_effects_other] = 'Yes'
                        a_hash[:side_effects_other_enc_id] = encounter.encounter_id
		end
	elsif obs.concept_id == 7567 #drug induced symptoms
                if obs.value_coded == 2148 && obs.value_coded_name_id == 2325
                        a_hash[:drug_induced_lipodystrophy] = 'Yes'
                        a_hash[:drug_induced_lipodystrophy_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 3 && obs.value_coded_name_id == 3
                        a_hash[:drug_induced_anemia] = 'Yes'
                        a_hash[:drug_induced_anemia_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 215 && obs.value_coded_name_id == 226
                        a_hash[:drug_induced_jaundice] = 'Yes'
                        a_hash[:drug_induced_jaundice_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 1458 && obs.value_coded_name_id == 1576
                        a_hash[:drug_induced_lactic_acidosis] = 'Yes'
                        a_hash[:drug_induced_lactic_acidosis_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 5945 && obs.value_coded_name_id == 4315
                        a_hash[:drug_induced_fever] = 'Yes'
                        a_hash[:drug_induced_fever_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 512 && obs.value_coded_name_id == 524
                        a_hash[:drug_induced_skin_rash] = 'Yes'
                        a_hash[:drug_induced_skin_rash_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 151 && obs.value_coded_name_id == 156
                        a_hash[:drug_induced_abdominal_pain] = 'Yes'
                        a_hash[:drug_induced_abdominal_pain_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 868 && obs.value_coded_name_id == 888
                        a_hash[:drug_induced_anorexia] = 'Yes'
                        a_hash[:drug_induced_anorexia_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 107 && obs.value_coded_name_id == 110
                        a_hash[:drug_induced_cough] = 'Yes'
                        a_hash[:drug_induced_cough_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 16 && obs.value_coded_name_id == 17
			a_hash[:drug_induced_diarrhea] = 'Yes'
                        a_hash[:drug_induced_diarrhea_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 7952 && obs.value_coded_name_id == 10894
			a_hash[:drug_induced_leg_pain_numbness] = 'Yes'
                        a_hash[:drug_induced_leg_pain_numbness_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 821 && obs.value_coded_name_id == 838
			a_hash[:drug_induced_peripheral_neuropathy = 'Yes'
                        a_hash[:drug_induced_peripheral_neuropathy_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 5980 && obs.value_coded_name_id == 4355
			a_hash[:drug_induced_vomiting] = 'Yes'
                        a_hash[:drug_induced_vomiting_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 6779 && obs.value_coded_name_id == 4355
			a_hash[:drug_induced_other_symptom] = 'Yes'
                        a_hash[:drug_induced_other_symptom_enc_id] = encounter.encounter_id
                elsif obs.value_coded == 29 && obs.value_coded_name_id == 30
			a_hash[:drug_induced_hepatitis] = 'Yes'
                        a_hash[:drug_induced_hepatitis_enc_id] = encounter.encounter_id
		end
 	end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_clinic_registration_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

  #initialize field and values variables
  fields = ""
  values = ""

  #create hiv_clinic_registration field list hash template

  a_hash{
    a_hash[:agrees_to_follow_up] => 'NULL',
    a_hash[:date_of_hiv_pos_test] => 'NULL',
    a_hash[:date_of_hiv_pos_test_estimated] => 'NULL',
    a_hash[:location_of_hiv_pos_test] => 'NULL',
    a_hash[:arv_number_at_that_site] => 'NULL',
    a_hash[:location_of_art_initiation] => 'NULL',
    a_hash[:taken_arvs_in_last_two_months] => 'NULL',
    a_hash[:taken_art_in_last_two_months_v_date] => 'NULL',
    a_hash[:taken_arvs_in_last_two_weeks] => 'NULL',
    a_hash[:has_transfer_letter] => 'NULL',
    a_hash[:site_transferred_from] => 'NULL',
    a_hash[:date_of_art_initiation] => 'NULL',
    a_hash[:ever_registered_at_art] => 'NULL',
    a_hash[:ever_registered_at_art_v_date] => 'NULL',
    a_hash[:ever_received_arv] => 'NULL',
    a_hash[:last_arv_regimen] => 'NULL',
    a_hash[:date_last_arv_taken] => 'NULL',
    a_hash[:date_art_last_taken_v_date] => 'NULL',
    a_hash[:weight] => 'NULL',
    a_hash[:height] => 'NULL',
    a_hash[:bmi] => 'NULL'
  }

  return generate_sql_string(a_hash) if type == 1

  (ecnounter || []).each do | obs |
    if obs.concept_id == 2552 #FOLLOW UP AGREEMENT
      a_hash[:agrees_to_follow_up] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7882 #CONFIRMATORY HIV TEST DATE
      a_hash[:date_of_hiv_pos_test] = obs.value_datetime.to_date rescue nil
    elsif obs.concept_id == 7437 #ESTIMATED DATE
      a_hash[:date_of_hiv_pos_test_estimated] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7881 #CONFIRMATORY HIV TEST LOCATION
      a_hash[:location_of_hiv_pos_test] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6981 #ART NUMBER AT PREVIOUS LOCATION
      a_hash[:arv_number_at_that_site] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7750 #LOCATION OF ART INITIATION
      a_hash[:location_of_art_initiation] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7752 #HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS
      a_hash[:taken_arvs_in_last_two_months] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6394 #HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS
      a_hash[:taken_arvs_in_last_two_weeks] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6393 #HAS TRANSFER LETTER
      a_hash[:has_transfer_letter] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1427 #TRANSFER IN FROM
      a_hash[:site_transferred_from] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2516 #DATE ANTIRETROVIRALS STARTED
      a_hash[:date_of_art_initiation] = obs.value_datetime.to_date rescue nil
    elsif obs.concept_id == 7937 #EVER REGISTERED AT ART CLINIC
      a_hash[:ever_registered_at_art] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7754 #EVER RECEIVED ART?
      a_hash[:ever_received_arv] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7753 #LAST ART DRUGS TAKEN
      a_hash[:last_arv_regimen] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7751 #DATE ART LAST TAKEN
      a_hash[:date_last_arv_taken] = obs.value_datetime.to_date rescue nil
    elsif obs.concept_id == 5089 #WEIGHT (KG)
      a_hash[:weight] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5090 #HEIGHT (CM)
      a_hash[:height] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2137 #BODY MASS INDEX, MEASURED
      a_hash[:bmi] = obs.to_s.split(':')[1].strip rescue nil
    end
  end

  return generate_sql_string(a_hash)
end

def process_hiv_staging_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

  #initialize field and values variables
  fields = ""
  values = ""

  #create hiv_staging field list hash template
  a_hash{
    :patient_pregnant => 'NULL',
    :is_patient_breast_feeding? => 'NULL',
    :cd4_count_location => 'NULL',
    :cd4_count => 'NULL',
    :cd4_count_modifier => 'NULL',
    :cd4_count_percentage => 'NULL',
    :date_of_cd4_count => 'NULL',
    :asymptomatic => 'NULL',
    :persistent_generalized_lymphadenopathy => 'NULL',
    :unspecified_stage_1_cond => 'NULL',
    :molluscumm_contagiosum => 'NULL',
    :wart_virus_infection_extensive => 'NULL',
    :oral_ulcerations_recurrent => 'NULL',
    :parotid_enlargement_persistent_unexplained => 'NULL',
    :lineal_gingival_erythema => 'NULL',
    :herpes_zoster => 'NULL',
    :respiratory_tract_infections_recurrent => 'NULL',
    :unspecified_stage2_condition => 'NULL',
    :angular_chelitis => 'NULL',
    :papular_prurtic_eruptions => 'NULL',
    :hepatosplenomegaly_unexplained => 'NULL',
    :oral_hairy_leukoplakia => 'NULL',
    :severe_weight_loss => 'NULL',
    :fever_persistent_unexplained => 'NULL',
    :pulmonary_tuberculosis => 'NULL',
    :pulmonary_tuberculosis_v_date => 'NULL',
    :pulmonary_tuberculosis_last_2_years => 'NULL',
    :pulmonary_tuberculosis_last_2_years_v_date => 'NULL',
    :severe_bacterial_infection => 'NULL',
    :bacterial_pnuemonia => 'NULL',
    :symptomatic_lymphoid_interstitial_pnuemonitis => 'NULL',
    :chronic_hiv_assoc_lung_disease => 'NULL',
    :unspecified_stage3_condition => 'NULL',
    :aneamia => 'NULL',
    :neutropaenia => 'NULL',
    :thrombocytopaenia_chronic => 'NULL',
    :diarhoea => 'NULL',
    :oral_candidiasis => 'NULL',
    :acute_necrotizing_ulcerative_gingivitis => 'NULL',
    :lymph_node_tuberculosis => 'NULL',
    :toxoplasmosis_of_brain => 'NULL',
    :cryptococcal_meningitis => 'NULL',
    :progressive_multifocal_leukoencephalopathy => 'NULL',
    :disseminated_mycosis => 'NULL',
    :candidiasis_of_oesophagus => 'NULL',
    :extrapulmonary_tuberculosis => 'NULL',
    :extrapulmonary_tuberculosis_v_date => 'NULL',
    :cerebral_non_hodgkin_lymphoma => 'NULL',
    :kaposis => 'NULL',
    :kaposis_sarcoma_v_date => 'NULL',
    :hiv_encephalopathy => 'NULL',
    :bacterial_infections_severe_recurrent => 'NULL',
    :unspecified_stage_4_condition => 'NULL',
    :pnuemocystis_pnuemonia => 'NULL',
    :disseminated_non_tuberculosis_mycobactierial_infection => 'NULL',
    :cryptosporidiosis => 'NULL',
    :isosporiasis => 'NULL',
    :symptomatic_hiv_asscoiated_nephropathy => 'NULL',
    :chronic_herpes_simplex_infection => 'NULL',
    :cytomegalovirus_infection => 'NULL',
    :toxoplasomis_of_the_brain_1month => 'NULL',
    :recto_vaginal_fitsula => 'NULL',
    :hiv_wasting_syndrome => 'NULL',
    :reason_for_starting_art => 'NULL',
    :reason_for_starting_v_date => 'NULL',
    :who_stage => 'NULL'
  }

  return generate_sql_string(a_hash) if type == 1

  (encounter || []).each do | obs |
    if obs.concept_id == 1755 #patient pregnant
      a_hash[:patient_pregnant] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7965 #is patient breast feeding?
      a_hash[:is_patient_breast_feeding?] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 9099 #cd4 count location
      a_hash[:cd4_count_location] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5497 #cd4_count
      a_hash[:cd4_count] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 9098 #cd4_count_modifier
      a_hash[:cd4_count_modifier] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 730 #cd4_count_percent
      a_hash[:cd4_count_percentage] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6831 #cd4_count_datetime
      a_hash[:date_of_cd4_count] = obs.value_datetime.to_date rescue nil
    elsif obs.concept_id == 5006 #asymptomatic
      a_hash[:asymptomatic] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5328 #persistent_generalized_lymphadenopathy
      a_hash[:persistent_generalized_lymphadenopathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6757 #unspecified_stage_1_cond
      a_hash[:unspecified_stage_1_cond] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1212 #molluscumm_contagiosum
      a_hash[:molluscumm_contagiosum] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6775 #wart_virus_infection_extensive
      a_hash[:wart_virus_infection_extensive] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2576 #oral_ulcerations_recurrent
      a_hash[:oral_ulcerations_recurrent] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1210 #parotid_enlargement_persistent_unexplained
      a_hash[:parotid_enlargement_persistent_unexplained] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2891 #lineal_gingival_erythema
      a_hash[:lineal_gingival_erythema] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 836 #herpes_zoster
      a_hash[:herpes_zoster] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5012 #respiratory_tract_infections_recurrent
      a_hash[:respiratory_tract_infections_recurrent] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6758 #unspecified_stage2_condition
      a_hash[:unspecified_stage2_condition] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2575 #angular_chelitis
      a_hash[:angular_chelitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2577 #papular_prurtic_eruptions
      a_hash[:papular_prurtic_eruptions] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7537 #hepatosplenomegaly_unexplained
      a_hash[:hepatosplenomegaly_unexplained] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5337 #oral_hairy_leukoplakia
      a_hash[:oral_hairy_leukoplakia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7540 #severe_weight_loss
      a_hash[:severe_weight_loss] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5027 #fever_persistent_unexplained
      a_hash[:fever_persistent_unexplained] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 8206 #pulmonary_tuberculosis
      a_hash[:pulmonary_tuberculosis] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 7539 #pulmonary_tuberculosis_last_2_years
      a_hash[:pulmonary_tuberculosis_last_2_years] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 5333 #severe_bacterial_infection
      a_hash[:severe_bacterial_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1215 #bacterial_pnuemonia
      a_hash[:bacterial_pnuemonia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5024 #symptomatic_lymphoid_interstitial_pnuemonitis
      a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2889 #chronic_hiv_assoc_lung_disease
      a_hash[:chronic_hiv_assoc_lung_disease] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6759 #unspecified_stage3_condition
      a_hash[:unspecified_stage3_condition] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 3 #aneamia
      a_hash[:aneamia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7954 #neutropaenia
      a_hash[:neutropaenia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7955 #thrombocytopaenia_chronic
      a_hash[:thrombocytopaenia_chronic] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 16 #diarhoea
      a_hash[:diarhoea] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5334 #oral_candidiasis
      a_hash[:oral_candidiasis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7546 #acute_necrotizing_ulcerative_gingivitis
      a_hash[:acute_necrotizing_ulcerative_gingivitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7547 #lymph_node_tuberculosis
      a_hash[:lymph_node_tuberculosis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2583 #toxoplasmosis_of_brain
      a_hash[:toxoplasmosis_of_brain] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1359 #cryptococcal_meningitis
      a_hash[:cryptococcal_meningitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5046 #progressive_multifocal_leukoencephalopathy
      a_hash[:progressive_multifocal_leukoencephalopathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7550 #disseminated_mycosis
      a_hash[:disseminated_mycosis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7553 #candidiasis_of_oesophagus
      a_hash[:candidiasis_of_oesophagus] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1547 #extrapulmonary_tuberculosis
      a_hash[:extrapulmonary_tuberculosis] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:extrapulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 2587 #cerebral_non_hodgkin_lymphoma
      a_hash[:cerebral_non_hodgkin_lymphoma] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 507 #kaposis
      a_hash[:kaposis] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:kaposis_sarcoma_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 1362 #hiv_encephalopathy
      a_hash[:hiv_encephalopathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2894 #bacterial_infections_severe_recurrent
      a_hash[:bacterial_infections_severe_recurrent] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6763 #unspecified_stage_4_condition
      a_hash[:unspecified_stage_4_condition] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 882 #pnuemocystis_pnuemonia
      a_hash[:pnuemocystis_pnuemonia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2585 #disseminated_non_tuberculosis_mycobactierial_infection
      a_hash[:disseminated_non_tuberculosis_mycobactierial_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5034 #cryptosporidiosis
      a_hash[:cryptosporidiosis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2858 #isosporiasis
      a_hash[:isosporiasis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7957 #symptomatic_hiv_asscoiated_nephropathy
      a_hash[:symptomatic_hiv_asscoiated_nephropathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5344 #chronic_herpes_simplex_infection
      a_hash[:chronic_herpes_simplex_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7551 #cytomegalovirus_infection
      a_hash[:cytomegalovirus_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5048 #toxoplasomis_of_the_brain_1month
      a_hash[:toxoplasomis_of_the_brain_1month] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7961 #recto_vaginal_fitsula
      a_hash[:recto_vaginal_fitsula] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 823 #hiv_wasting_syndrome
      a_hash[:hiv_wasting_syndrome] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7563 #reason_for_starting_art
      a_hash[:reason_for_starting_art] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:reason_for_starting_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 7562 #who_stage
      a_hash[:who_stage] = obs.to_s.split(':')[1].strip rescue nil
    else
    end
  end

  return generate_sql_string(a_hash)
end

def process_patient_orders(orders)
  patient_orders = {}
  drug_dose_hash = {}; drug_frequency_hash = {};
  drug_equivalent_daily_dose_hash = {}; drug_inventory_ids_hash = {}
  patient_orders = {}; drug_order_ids_hash = {}; drug_enc_ids_hash = {}
  drug_start_date_hash = {}; drug_auto_expire_date_hash = {}; drug_quantity_hash = {}
  
  (orders || []).each do |ord|
    drug_name = Drug.find(ord.drug_inventory_id).name

    if patient_orders[drug_name].blank?
      patient_orders[drug_name] = drug_name
      drug_order_ids_hash[drug_name] = ord.order_id
      drug_enc_ids_hash[drug_name] = ord.encounter_id
      drug_start_date_hash[drug_name] = ord.start_date
      drug_auto_expire_date_hash[drug_name] = ord.auto_expire_date
      drug_quantity_hash[drug_name] = ord.quantity
      drug_dose_hash[drug_name] = ord.dose
      drug_frequency_hash[drug_name] = ord.frequency
      drug_equivalent_daily_dose_hash[drug_name] = ord.equivalent_daily_dose
      drug_inventory_ids_hash[drug_name] = ord.drug_inventory_id
    else
      patient_orders[drug_name] += drug_name
      drug_order_ids_hash[drug_name] += ord.order_id
      drug_enc_ids_hash[drug_name] += ord.encounter_id
      drug_start_date_hash[drug_name] += ord.start_date
      drug_auto_expire_date_hash[drug_name] += ord.auto_expire_date
      drug_quantity_hash[drug_name] += ord.quantity
      drug_dose_hash[drug_name] += ord.dose
      drug_frequency_hash[drug_name] += ord.frequency
      drug_equivalent_daily_dose_hash[drug_name] += ord.equivalent_daily_dose
      drug_inventory_ids_hash[drug_name] += ord.drug_inventory_id    
    end
  end

  count = 1
  (patient_orders).each do |drug_name, name|
    case count
      when 1
       a_hash[:drug_name1] = drug_name
       a_hash[:drug_order_id1] = drug_order_ids_hash[drug_name]
       a_hash[:start_date1] = drug_start_date_hash[drug_name]
       a_hash[:auto_expire_date1] = drug_auto_expire_date_hash[drug_name]
       a_hash[:quantity1] = drug_quantity_hash[drug_name]
       a_hash[:frequency1] = drug_frequency_hash[drug_name]
       a_hash[:dose1] = drug_dose_hash[drug_name]
       a_hash[:equivalent_daily_dose1] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:encounter_id1] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id1] = drug_inventory_ids_hash[drug_name] 
       count += 1
      when 2
       a_hash[:drug_name2] = drug_name
       a_hash[:drug_order_id2] = drug_order_ids_hash[drug_name]
       a_hash[:start_date2] = drug_start_date_hash[drug_name]
       a_hash[:auto_expire_date2] = drug_auto_expire_date_hash[drug_name]
       a_hash[:quantity2] = drug_quantity_hash[drug_name]
       a_hash[:frequency2] = drug_frequency_hash[drug_name]
       a_hash[:dose2] = drug_dose_hash[drug_name]
       a_hash[:equivalent_daily_dose2] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:encounter_id2] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id2] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 3
       a_hash[:drug_name3] = drug_name
       a_hash[:drug_order_id3] = drug_order_ids_hash[drug_name]
       a_hash[:start_date3] = drug_start_date_hash[drug_name]
       a_hash[:auto_expire_date3] = drug_auto_expire_date_hash[drug_name]
       a_hash[:quantity3] = drug_quantity_hash[drug_name]
       a_hash[:frequency3] = drug_frequency_hash[drug_name]
       a_hash[:dose3] = drug_dose_hash[drug_name]
       a_hash[:equivalent_daily_dose3] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:encounter_id3] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id3] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 4
       a_hash[:drug_name4] = drug_name
       a_hash[:drug_order_id4] = drug_order_ids_hash[drug_name]
       a_hash[:start_date4] = drug_start_date_hash[drug_name]
       a_hash[:auto_expire_date4] = drug_auto_expire_date_hash[drug_name]
       a_hash[:quantity4] = drug_quantity_hash[drug_name]
       a_hash[:frequency4] = drug_frequency_hash[drug_name]
       a_hash[:dose4] = drug_dose_hash[drug_name]
       a_hash[:equivalent_daily_dose4] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:encounter_id4] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id4] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 5
       a_hash[:drug_name5] = drug_name
       a_hash[:drug_order_id5] = drug_order_ids_hash[drug_name]
       a_hash[:start_date5] = drug_start_date_hash[drug_name]
       a_hash[:auto_expire_date5] = drug_auto_expire_date_hash[drug_name]
       a_hash[:quantity5] = drug_quantity_hash[drug_name]
       a_hash[:frequency5] = drug_frequency_hash[drug_name]
       a_hash[:dose5] = drug_dose_hash[drug_name]
       a_hash[:equivalent_daily_dose5] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:encounter_id5] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id5] = drug_inventory_ids_hash[drug_name]
       count += 1    
      end
  end
  return generate_sql_string(a_hash)
end

def generate_sql_string(a_hash)

    a_hash.each do |key,value|
        fields += fields.empty? ? "`#{key}`" : ", `#{key}`"
        values += values.empty? ? "`#{value}`" : ", `#{value}`"
    end

    return [fields, values]
end

def start
 initialize
 get_all_patients
end

