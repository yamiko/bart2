
def init_variables
  #set Location first
  site_id = GlobalProperty.find_by_property('current_health_center_id').property_value

  location = Location.find(site_id)
  Location.current_location = location
end


def start

  init_variables
  puts "Starting to void"
  encounters_to_void = []
  staging = []
  art_visit = []
  File.open('./hiv_staging_to_void.txt', 'r') do |file|
    while line = file.gets
      staging = line.split(",")
    end
  end

  File.open('./art_visit_to_void.txt', 'r') do |file|
    while line = file.gets
      art_visit = line.split(",")
    end
  end


  encounters_to_void = staging + art_visit
  puts "#{encounters_to_void.length} to be voided"


  Encounter.transaction do

    Observation.update_all({:voided => 1, :voided_by => 1,:date_voided => Time.now,  :void_reason => 'Migration Errors'},["encounter_id in (?)", encounters_to_void])
    Encounter.update_all({:voided => 1, :voided_by => 1,:date_voided => Time.now, :void_reason => 'Migration Errors'},["encounter_id in (?)", encounters_to_void])

  end



end

start