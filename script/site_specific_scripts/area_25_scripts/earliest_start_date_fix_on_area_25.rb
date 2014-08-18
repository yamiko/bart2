=begin

Creator 	:     	Precious Ulemu Bondwe
Date    	:     	2013-08-28 
Purpose 	:     	To void all adherence encounters with their corresponding observations. 
	              	This allows recalculation of adherence in case adherence was not calculated properly. 
pre-requisite	:	MAKE SURE THE location_id IS SET TO THE LOCATION ID OF THE HEALTH CENTER THE MIGRATION IS FOR:
amendments	:	********** INCLUDE AMENDMENTS HERE  ***************
=end

def start

all_wrong_earliest_start_dates = Encounter.find_by_sql("select e.patient_id, e.encounter_type, o.concept_id, e.encounter_datetime, esd.earliest_start_date FROM encounter e
	                                    inner join obs o on o.encounter_id = e.encounter_id and o.concept_id = 2559 and e.encounter_type = 54
	                                    inner join earliest_start_date esd on esd.patient_id = e.patient_id and esd.earliest_start_date <> DATE(e.encounter_datetime)
                                    Where e.encounter_datetime = (Select min(obs_datetime) from obs 
							                                    where person_id = e.patient_id 
							                                    and obs.concept_id = 2559 
							                                    and o.voided = 0)
                                    GROUP BY e.patient_id
                                    ORDER BY e.patient_id")

counter_all_start_dates = all_wrong_earliest_start_dates.length

(all_wrong_earliest_start_dates || []).each do |enc|
  patient_id = enc.patient_id
  correct_start_date = enc.encounter_datetime.strftime('%Y-%m-%d 00:00:00')

ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program
SET date_enrolled = '#{enc.encounter_datetime.strftime('%Y-%m-%d 00:00:00')}'
WHERE patient_id = #{patient_id}
AND program_id = 1
EOF

patient_program_id = PatientProgram.find(:all, :conditions => ["patient_id = ? AND program_id = ? AND date_enrolled = ?",patient_id, 1, correct_start_date]).map(&:patient_program_id).first

ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_state
SET start_date = '#{enc.encounter_datetime.strftime('%Y-%m-%d 00:00:00')}',
date_created = '#{enc.encounter_datetime.strftime('%Y-%m-%d 00:00:00')}'
WHERE patient_program_id = #{patient_program_id}
AND state = 7
EOF


puts">>>>>>>#{enc.patient_id}....#{enc.encounter_datetime.to_date}.........#{counter_all_start_dates -= 1} patients to go..."
end

end
start
