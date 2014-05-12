
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

   visits.each do |visit|
	encounters = Encounter.find(:all,
			:include => [:observations],
			:conditions => ['voided = 0 AND patient_id = ? AND date(encounter_datetime) = ?', patient_id, visit])

	
   end
end

def start
 initialize
 get_all_patients
end
