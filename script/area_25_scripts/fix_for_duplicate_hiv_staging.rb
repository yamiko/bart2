def start

  source_db = 'bart1_area_25'
  target_db = 'area_25_to_be_fixed'
  bart1_hiv_staging_enc_id = 5
  bart2_hiv_staging_enc_id = EncounterType.find_by_name("HIV STAGING").id
  encounters_to_import = []
  encounters_to_void = []
  count = 0

  to_void = File.open('./hiv_staging_to_void.txt', "w")
  to_import = File.open('./hiv_staging_to_import.txt', "w")

  all_patients = Patient.find_by_sql("SELECT
											e.patient_id,
											count(e.patient_id) as count,
											DATE(e.encounter_datetime) as encounter_datetime
										FROM
											#{source_db}.encounter e
										WHERE
											e.encounter_type = #{bart1_hiv_staging_enc_id}
										group by e.patient_id , DATE(e.encounter_datetime)
										having count > 1")

  puts "Patients with duplicate ARV Encounters >>>>>>>> #{all_patients.count}"


  (all_patients || []).each do |patient|

    puts "working with patient id #{patient.patient_id}, Encounter Date #{patient.encounter_datetime}"
    get_encs_to_migrate = Encounter.find_by_sql("Select max(encounter_id) as encounter_id
                                                  from #{source_db}.encounter
                                                  where patient_id = #{patient.patient_id} and
                                                  DATE(encounter_datetime) = '#{patient.encounter_datetime}' AND
                                                  encounter_type = #{bart1_hiv_staging_enc_id} group by DATE(encounter_datetime)")



    puts " migrate #{get_encs_to_migrate.length}"

    (get_encs_to_migrate || []).each  do |max_enc|

      puts "Max encounter id #{max_enc.encounter_id}"
      check_existence = Encounter.find(max_enc.encounter_id)  rescue nil

      if check_existence.blank?
        puts "Encounter not found"
        encounter_on_date = Encounter.find_by_sql("SELECT * FROM encounter where patient_id = #{patient.patient_id} AND
                                                  encounter_type = #{bart2_hiv_staging_enc_id} AND
                                                  DATE(encounter_datetime) = DATE('#{patient.encounter_datetime}')")


        (encounter_on_date || []).each do |void|

          encounters_to_void << void.id

        end

        encounters_to_import << max_enc.id

      end

    end

  end

  puts ">>>>> Encounters to be voided >>>>>>>>>>>"
  puts "#{encounters_to_void.join(', ')}"
  to_void << encounters_to_void.join(', ')
  puts "<<<<<< End of encounters to be voided <<<<<<<<<"

  puts ">>>>> Encounters to be imported >>>>>>>>>>>"
  puts "#{encounters_to_import.join(', ')}"
  to_import << encounters_to_import.join(', ')
  puts "<<<<<< End of Encounters to be imported <<<<<<<<<"

  to_import.close()
  to_void.close()


end

start