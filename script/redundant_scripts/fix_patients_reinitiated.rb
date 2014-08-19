=begin

Purpose : To void 'Taken ARVs in the past two months' observation when the patient
         also have 'Date ART last taken' observation during the same visit.

=end
require 'yaml'

if ARGV[0].nil?
  raise "Please include the environment that you would like to choose. Either development or production"
else
  @environment = ARGV[0]
end


def initialize_variables
  @source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))["#{@environment}"]["database"]
  @started_at = Time.now.strftime("%Y-%m-%d-%H%M%S")
end

def start
  
  patients_re_initiated = Encounter.find_by_sql("SELECT 
                              esd.patient_id,
                              esd.earliest_start_date,
                              o.encounter_id,
                              o.concept_id AS art_last_taken_concept,
                              o.value_datetime AS art_last_taken_date,
                              o.obs_datetime AS encounter_date,
                              dt.concept_id AS taken_arvs_in_last_2_months,
	                            dt.value_coded AS taken_arvs_in_last_2_months_answer
                          FROM
                              #{@source_db}.earliest_start_date esd
                                  LEFT JOIN
                              #{@source_db}.clinic_registration_encounter e ON esd.patient_id = e.patient_id
                                  INNER JOIN
                              
                              #{@source_db}.obs o ON o.encounter_id = e.encounter_id
                                  AND o.concept_id IN (7751)
                                  INNER JOIN
                              (SELECT 
                                  esd.patient_id, o.encounter_id, o.concept_id, o.value_coded
                              FROM
                                  #{@source_db}.earliest_start_date esd
                              LEFT JOIN #{@source_db}.clinic_registration_encounter e ON esd.patient_id = e.patient_id

                              LEFT JOIN #{@source_db}.obs o ON o.encounter_id = e.encounter_id
                                  AND o.concept_id IN (7752)
                              WHERE
                                  ((o.concept_id = 7752) AND o.voided = 0)) as dt ON dt.encounter_id = o.encounter_id
                          WHERE
                              (o.concept_id = 7751 AND o.voided = 0)")

  patients_re_initiated.each do |patient|
        ActiveRecord::Base.connection.execute <<EOF
UPDATE #{@source_db}.obs
SET voided = 1, voided_by = 1, date_voided = '#{Date.today.strftime("%Y-%m-%d %H:%M:%S")}'
WHERE encounter_id = #{patient.encounter_id}
AND concept_id = 7752
AND person_id = #{patient.patient_id}
AND voided = 0
EOF

  puts "working on patient_id #{patient.patient_id} >>>>>>>"     
  end                            

end


start
