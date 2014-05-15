
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

