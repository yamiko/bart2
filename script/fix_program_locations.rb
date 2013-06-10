
def update_locations

  PatientProgram.update_all("location_id = "+ Location.current_health_center.location_id.to_s )

end

update_locations