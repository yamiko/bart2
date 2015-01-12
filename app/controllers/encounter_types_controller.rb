class EncounterTypesController < GenericEncounterTypesController

  def index
    role_privileges = RolePrivilege.find(:all,:conditions => ["role IN (?)", current_user_roles])
    privileges = role_privileges.each.map{ |role_privilege_pair| role_privilege_pair["privilege"].humanize }
 
    @encounter_privilege_map = CoreService.get_global_property_value("encounter_privilege_map").to_s rescue ''
    @encounter_privilege_map = @encounter_privilege_map.split(",")
    @encounter_privilege_hash = {}

    @encounter_privilege_map.each do |encounter_privilege|
        @encounter_privilege_hash[encounter_privilege.split(":").last.squish.humanize] = encounter_privilege.split(":").first.squish.humanize
    end

    roles_for_the_user = []

    privileges.each do |privilege|
      roles_for_the_user  << @encounter_privilege_hash[privilege] if !@encounter_privilege_hash[privilege].nil?
    end
    roles_for_the_user = roles_for_the_user.uniq

    # TODO add clever sorting
    @encounter_types = EncounterType.find(:all).map{|enc|enc.name.gsub(/.*\//,"").gsub(/\..*/,"").humanize}
    @available_encounter_types = Dir.glob(RAILS_ROOT+"/app/views/encounters/*.rhtml").map{|file|file.gsub(/.*\//,"").gsub(/\..*/,"").humanize}

    @available_encounter_types -= @available_encounter_types - @encounter_types

    @available_encounter_types = ((@available_encounter_types) - ((@available_encounter_types - roles_for_the_user) + (roles_for_the_user - @available_encounter_types)))
    if CoreService.get_global_property_value("activate.htn.enhancement").to_s == "true" && patient_present(Patient.find(params[:patient_id]), (session[:datetime].to_date rescue Date.today)) && htn_client?(Patient.find(params[:patient_id]))
     @available_encounter_types << "BP Management"
    end
    @available_encounter_types = @available_encounter_types.sort

  end

  def show
   if params["encounter_type"].downcase == "bp management"
    redirect_to "/htn_encounter/bp_management?#{params.to_param}" and return
   else
    redirect_to "/encounters/new/#{params["encounter_type"].downcase.gsub(/ /,"_")}?#{params.to_param}" and return
   end

  end

end
