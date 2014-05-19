
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
   visits = Encounter.find_by_sql("SELECT date(encounter_datetime) AS visit_date FROM #{@source_db}.encounter 
				WHERE patient_id = #{patient_id} AND voided = 0  
					group_by date(encounter_datetime)".map(&:visit_date)

#list of encounters for bart2
#vitals => 6, appointment => 7, treatment => 25, hiv clinic consultation => 53, hiv_reception => 51
   initial_string = "INSERT INTO flat_table2 "

   visits.each do |visit|
	# arrays of [fields, values]
	vitals = []
	appointment = []
	hiv_clinic_consultation = []
	hiv_reception = []	

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
    sql_statement = initial_string + "(" + vitals[0] + appointment[0] + hcc[0] + hiv_reception[0] ")" + \
		 " VALUES (" + vitals[1] + appointment[1] + hcc[1] + hiv_reception[1] + ");"
	
    $temp_outfile = File.open("./migration_output/flat_table_2-" + @started_at + ".sql", "w") 
    $temp_outfile << sql_statement
    $temp_outfile.close
	
   end
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
		:pregnant_yes_enc_id => '',
		:pregnant_no => '',
		:pregnant_no_enc_id => '',
		:breastfeeding_yes => ''
                :breastfeeding_yes_enc_id => 'NULL',
		:breastfeeding_no => '',
		:breastfeeding_no_enc_id => '',
                :currently_using_family_planning_method_yes => 'NULL',
                :currently_using_family_planning_method_yes_enc_id => 'NULL',
                :currently_using_family_planning_method_no => 'NULL',
                :currently_using_family_planning_method_no_enc_id => 'NULL',
		:family_planning_method_oral_contraceptive_pills => '',
		:family_planning_method_oral_contraceptive_pills_enc_id => '',
		:family_planning_method_depo_provera => '',
		:family_planning_method_depo_provera_enc_id => '',
		:family_planning_method_intrauterine_contraception => '',
		:family_planning_method_intrauterine_contraception_enc_id => '',
		:family_planning_method_contraceptive_implant => '',
		:family_planning_method_contraceptive_implant_enc_id => '',
		:family_planning_method_male_condoms => '',
		:family_planning_method_male_condoms_enc_id => '',
		:family_planning_method_female_condoms => '',
		:family_planning_method_female_condoms_enc_id => '',
		:family_planning_method__rythm_method => '',
		:family_planning_method__rythm_method_enc_id => '',
		:family_planning_method_withdrawal => '',
		:family_planning_method_withdrawal_enc_id => '',
		:family_planning_method_abstinence => '',
		:family_planning_method_abstinence_enc_id => '',
		:family_planning_method_tubal_ligation => '',
		:family_planning_method_tubal_ligation_enc_id => '',
		:family_planning_method_emergency__contraception => '',
		:family_planning_method_emergency__contraception_enc_id => '',
		:family_planning_method_vasectomy => '',
		:family_planning_method_vasectomy_enc_id => '',
                :family_planning_method_used => 'NULL',
		:symptom_present_lipodystrophy => '',        
		:symptom_present_lipodystrophy_enc_id => '',        
		:symptom_present_anemia => '',        
		:symptom_present_anemia_enc_id => '',        
		:symptom_present_jaundice => '',        
		:symptom_present_jaundice_enc_id => '',        
		:symptom_present_lactic_acidosis => '',        
		:symptom_present_lactic_acidosis_enc_id => '',        
		:symptom_present_fever => '',        
		:symptom_present_fever_enc_id => '',        
		:symptom_present_skin_rash => '',        
		:symptom_present_skin_rash_enc_id => '',        
		:symptom_present_abdominal_pain => '',        
		:symptom_present_abdominal_pain_enc_id => '',        
		:symptom_present_anorexia => '',        
		:symptom_present_anorexia_enc_id => '',        
		:symptom_present_cough => '',        
		:symptom_present_cough_enc_id => '',        
		:symptom_present_diarrhea => '',        
		:symptom_present_diarrhea_enc_id => '',        
		:symptom_present_hepatitis => '',        
		:symptom_present_hepatitis_enc_id => '',        
		:symptom_present_leg_pain_numbness => '',        
		:symptom_present_leg_pain_numbness_enc_id => '',        
		:symptom_present_peripheral_neuropathy => '',        
		:symptom_present_peripheral_neuropathy_enc_id => '',        
		:symptom_present_vomiting => '',        
		:symptom_present_vomiting_enc_id => '',        
		:symptom_present_other_symptom => '',        
		:symptom_present_other_symptom_enc_id => '',        
		:side_effects_peripheral_neuropathy => '',
		:side_effects_peripheral_neuropathy_enc_id => '',
		:side_effects_peripheral_hepatitis => '',
		:side_effects_peripheral_hepatitis_enc_id => '',
		:side_effects_peripheral_skin_rash => '',
		:side_effects_peripheral_skin_rash_enc_id => '',
		:side_effects_peripheral_lipodystrophy => '',
		:side_effects_peripheral_lipodystrophy_enc_id => '',
		:side_effects_peripheral_other => '',
		:side_effects_peripheral_other_enc_id => '',
		:drug_induced_abdominal_pain => '',
		:drug_induced_abdominal_pain_enc_id => '',
		:drug_induced_anorexia => '',
		:drug_induced_anorexia_enc_id => '',
		:drug_induced_diarrhea => '',
		:drug_induced_diarrhea_enc_id => '',
		:drug_induced_jaundice => '',
		:drug_induced_jaundice_enc_id => '',
		:drug_induced_leg_pain_numbness => '',
		:drug_induced_leg_pain_numbness_enc_id => '',
		:drug_induced_vomiting => '',
		:drug_induced_vomiting_enc_id => '',
		:drug_induced_peripheral_neuropathy => '',
		:drug_induced_peripheral_neuropathy_enc_id => '',
		:drug_induced_hepatitis => '',
		:drug_induced_hepatitis_enc_id => '',
		:drug_induced_anemia => '',
		:drug_induced_anemia_enc_id => '',
		:drug_induced_lactic_acidosis => '',
		:drug_induced_lactic_acidosis_enc_id => '',
		:drug_induced_lipodystrophy => '',
		:drug_induced_lipodystrophy_enc_id => '',
		:drug_induced_skin_rash => '',
		:drug_induced_skin_rash_enc_id => '',
		:drug_induced_other_symptom => '',
		:drug_induced_other_symptom_enc_id => '',
		:drug_induced_fever => '',
		:drug_induced_fever_enc_id => '',
		:drug_induced_cough => '',
		:drug_induced_cough_enc_id => '',
        :abdominal_pains => 'NULL',
                :anorexia => 'NULL',
                :cough => 'NULL',
                :diarrhoea => 'NULL',
	 	:fever => '',
	 	:jaundice => '',
		:leg_pain_numbness => '',
		:vomit => '',
		:weight_loss => '',
		:peripheral_neuropathy => '',
		:hepatitis => '',
		:anaemia => '',
		:lactic_acidosis => '',
		:lipodystrophy => '',
		:skin_rash => '',
		:other_symptoms => ''
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

  (ecnounter.observations || []).each do | obs |
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

  (encounter.observations || []).each do | obs |
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

