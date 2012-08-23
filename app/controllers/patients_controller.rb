class PatientsController < GenericPatientsController
  
  def exitcare_dashboard
    @patient = Patient.find(params[:id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
  
    render :template => 'dashboards/exitcare_dashboard.rhtml', :layout => false
  end
  def exitcare
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
      render :template => 'dashboards/exitcare_tab', :layout => false
  end
  def exitcare_history
    @patient = Patient.find(params[:patient_id])
    encounter_type = EncounterType.find_by_name("EXIT FROM CARE").id

    @encounters = Encounter.find(:all,  
                  :conditions => [" patient_id = ? AND encounter_type = ?", 
                                  @patient.id, encounter_type]) 
    @creator_name = {}
    @encounters.each do |encounter|
      id = encounter.creator
      user_name = User.find(id).person.names.first
      @creator_name[id] = '(' + user_name.given_name.first + '. ' + user_name.family_name + ')'
    end
  
    render :template => 'dashboards/exitcare_tab', :layout => false
  end

end
