
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
	hcc = []
	hiv_reception = []	

	encounters = Encounter.find(:all,
			:include => [:observations],
			:order => "encounter_datetime ASC"
			:conditions => ['voided = 0 AND patient_id = ? AND date(encounter_datetime) = ?', patient_id, visit])
	
	encounters.each do |enc|
		if enc.encounter_type == 6 #vitals
			vitals = process_vitals_encounter(encounter)
		elsif enc.encounter_type == #HIV reception

		elsif

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
    vitals_hash = {:height => 0,
		   :weight => 0,
		   :temperature => 0,
		   :bmi => 0,
		   :systolic_blood_pressure => 0,
		   :diastolic_blood_pressure => 0,
		   :weight_for_height => 0,
		   :weight_for_age => 0,
		   :height_for_age => 0
		}
	
    return generate_sql_string(vitals_hash) if type == 1 

    encounter.observations.each do |obs|
	if obs.concept_id == 5089 #weight
		vitals_hash[:weight] = obs.value_numeric
	elsif obs.concept_id == 5090 #height
		vitals_hash[:height] = obs.value_numeric
	elsif obs.concept_id == 5088 #temperature
		vitals_hash[:temperature] = obs.value_numeric
	elsif obs.concept_id == 2137 #bmi
		vitals_hash[:bmi] = obs.value_numeric
        elsif obs.concept_id == 5085 #systolic blood pressure
		vitals_hash[:systolic_blood_pressure] = obs.value_numeric
        elsif obs.concept_id == 5086 #diastolic blood pressure
		vitals_hash[:diastolic_blood_pressure] = obs.value_numeric
        elsif obs.concept_id == 1822 #weight for height
		vitals_hash[:weight_for_height] = obs.value_numeric
        elsif obs.concept_id == 6396 #weight for age
		vitals_hash[:weight_for_age] = obs.value_numeric
        elsif obs.concept_id == 6397 #height_for_age 
		vitals_hash[:height_for_age] = obs.value_numeric
	end
    end

    return generate_sql_string(vitals_hash)
end

def process_vitals_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash = {:height => 0,
                   :weight => 0,
                   :temperature => 0,
                   :bmi => 0,
                   :systolic_blood_pressure => 0,
                   :diastolic_blood_pressure => 0,
                   :weight_for_height => 0,
                   :weight_for_age => 0,
                   :height_for_age => 0
                }

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
        if obs.concept_id == 5089 #weight
                a_hash[:weight] = obs.value_numeric
        elsif obs.concept_id == 5090 #height
                a_hash[:height] = obs.value_numeric
        elsif obs.concept_id == 5088 #temperature
                a_hash[:temperature] = obs.value_numeric
        elsif obs.concept_id == 2137 #bmi
                a_hash[:bmi] = obs.value_numeric
        elsif obs.concept_id == 5085 #systolic blood pressure
                a_hash[:systolic_blood_pressure] = obs.value_numeric
        elsif obs.concept_id == 5086 #diastolic blood pressure
                a_hash[:diastolic_blood_pressure] = obs.value_numeric
        elsif obs.concept_id == 1822 #weight for height
                a_hash[:weight_for_height] = obs.value_numeric
        elsif obs.concept_id == 6396 #weight for age
                a_hash[:weight_for_age] = obs.value_numeric
        elsif obs.concept_id == 6397 #height_for_age 
                a_hash[:height_for_age] = obs.value_numeric
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

