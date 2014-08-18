require 'mysql'

$mysql_conn = Mysql.new(ARGV[0], ARGV[1], ARGV[2],ARGV[3])

def start

  encounters = $mysql_conn.query("SELECT * FROM temp_encounter")
  count = encounters.num_rows
  puts "#{count} encounters to be migrated"
  (encounters || []).each do |encounter|
    puts "#{count} encounters to go"
    Encounter.transaction do
      new_encounter = Encounter.new()
      new_encounter.encounter_type = encounter[1]
      new_encounter.patient_id = encounter[2].to_i
      new_encounter.provider = Person.find(encounter[3].to_i)
      new_encounter.location_id = encounter[4].to_i
      new_encounter.encounter_datetime = encounter[6]
      new_encounter.creator = encounter[7].to_i
      new_encounter.uuid = encounter[13]
      if new_encounter.save

        observations = $mysql_conn.query("SELECT * FROM temp_obs WHERE encounter_id = #{encounter[0]}")

        (observations || []).each do |obs|
          new_obs = Observation.new()
          new_obs.person_id = obs[1].to_i
          new_obs.concept_id = obs[2].to_i
          new_obs.encounter_id = new_encounter.id
          new_obs.order_id = (obs[4].to_i == 0) ? nil : obs[4].to_i
          new_obs.obs_datetime = obs[5]
          new_obs.location_id = obs[6].to_i
          new_obs.obs_group_id = obs[7]
          new_obs.accession_number = obs[8]
          new_obs.value_group_id = obs[9]
          new_obs.value_boolean = obs[10]
          new_obs.value_coded =  (obs[11].to_i == 0) ? nil : obs[11].to_i
          new_obs.value_coded_name_id = obs[12]
          new_obs.value_drug =  (obs[13].to_i == 0) ? nil : obs[13].to_i
          new_obs.value_datetime = obs[14]
          new_obs.value_numeric =  (obs[15].to_i == 0) ? nil : obs[15].to_i
          new_obs.value_modifier = obs[16]
          new_obs.value_text = obs[17]
          new_obs.date_started = obs[18]
          new_obs.date_stopped = obs[19]
          new_obs.comments = obs[20]
          new_obs.creator = obs[21].to_i
          new_obs.date_created = obs[22]
          new_obs.voided = obs[23]
          new_obs.voided_by = obs[24]
          new_obs.date_voided = obs[25]
          new_obs.void_reason = obs[26]
          new_obs.value_complex = obs[27]
          new_obs.uuid = obs[28]
          new_obs.save
        end

      end
    end
    count -=1
  end

end

start