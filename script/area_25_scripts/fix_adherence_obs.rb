=begin

Creator 	:     	Precious Ulemu Bondwe
Date    	:     	2013-08-28 
Purpose 	:     	To void all adherence encounters with their corresponding observations. 
	              	This allows recalculation of adherence in case adherence was not calculated properly. 
pre-requisite	:	MAKE SURE THE location_id IS SET TO THE LOCATION ID OF THE HEALTH CENTER THE MIGRATION IS FOR:
amendments	:	********** INCLUDE AMENDMENTS HERE  ***************
=end

def start

     ActiveRecord::Base.connection.execute <<EOF
DELETE FROM obs
WHERE concept_id = 6987
EOF


all_voided_adh = Encounter.find_by_sql("SELECT * FROM encounter WHERE encounter_type = 68 AND voided = 1")


(all_voided_adh || []).each do |enc|
  patient_id = enc.patient_id
  start_date = enc.encounter_datetime.strftime('%Y-%m-%d 00:00:00')
  end_date = enc.encounter_datetime.strftime('%Y-%m-%d 23:59:59')
  
  voided_enc = Encounter.find(:all, :conditions => ["encounter_type = ? AND voided = 0 AND patient_id = ?
  AND encounter_datetime BETWEEN ? AND ?", 68, patient_id, start_date, end_date])
  
  if voided_enc.blank?
ActiveRecord::Base.connection.execute <<EOF
UPDATE obs
SET voided = 0, voided_by = NULL, void_reason = NULL, date_voided = NULL
WHERE encounter_id = #{enc.encounter_id}
EOF

ActiveRecord::Base.connection.execute <<EOF
UPDATE encounter
SET voided = 0, voided_by = NULL, void_reason = NULL, date_voided = NULL
WHERE encounter_id = #{enc.encounter_id}
EOF

		puts ">>>>> #{enc.encounter_id}"
    end
  end


all_voided_adh = Encounter.find_by_sql("SELECT * FROM encounter e
  INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = 2540 AND o.voided = 1
AND encounter_type = 68")


(all_voided_adh || []).each do |enc|
  patient_id = enc.patient_id
  start_date = enc.encounter_datetime.strftime('%Y-%m-%d 00:00:00')
  end_date = enc.encounter_datetime.strftime('%Y-%m-%d 23:59:59')
  
  un_voided_enc = Encounter.find(:all, :conditions => ["encounter_type = ? AND voided = 0 AND patient_id = ?
  AND encounter_datetime BETWEEN ? AND ?", 68, patient_id, start_date, end_date])
  
  if not un_voided_enc.blank?
ActiveRecord::Base.connection.execute <<EOF
UPDATE obs
SET voided = 1, voided_by = 1, void_reason = 'migration fix', date_voided = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}'
WHERE encounter_id = #{un_voided_enc.first.encounter_id}
EOF

ActiveRecord::Base.connection.execute <<EOF
UPDATE obs
SET voided = 1, voided_by = 1, void_reason = 'migration fix', date_voided = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}'
WHERE encounter_id = #{un_voided_enc.first.encounter_id}
EOF

ActiveRecord::Base.connection.execute <<EOF
UPDATE encounter
SET voided = 0, voided_by = NULL, void_reason = NULL, date_voided = NULL
WHERE encounter_id = #{enc.encounter_id}
EOF

ActiveRecord::Base.connection.execute <<EOF
UPDATE obs
SET voided = 0, voided_by = NULL, void_reason = NULL, date_voided = NULL
WHERE encounter_id = #{enc.encounter_id}
EOF



		puts ">>>>> #{enc.encounter_id}"
    elsif un_voided_enc.blank? 
    ActiveRecord::Base.connection.execute <<EOF
UPDATE encounter
SET voided = 0, voided_by = NULL, void_reason = NULL, date_voided = NULL
WHERE encounter_id = #{enc.encounter_id}
EOF

ActiveRecord::Base.connection.execute <<EOF
UPDATE obs
SET voided = 0, voided_by = NULL, void_reason = NULL, date_voided = NULL
WHERE encounter_id = #{enc.encounter_id}
EOF

    end
  end




end
start
