class PropertiesController < GenericPropertiesController
	def export_cohort_data
		 if request.post? and not params[:export_cohort_data].blank?
			 session["export.cohort.data"] = params[:export_cohort_data]
      redirect_to '/clinic' and return
    end
	end

	def staging_options
		all_settings = ["use.normal.staging.questions","use.extended.staging.questions","use.standard.staging.questions"]
		property = "use.normal.staging.questions" if params['staging_options'].to_s.match(/normal/i)
		property = "use.extended.staging.questions" if params['staging_options'].to_s.match(/extended/i)
		property = "use.standard.staging.questions" if params['staging_options'].to_s.match(/standard/i)
		all_settings.each do | setting |
			global_setting = GlobalProperty.find_by_property(setting)
			global_setting.property_value = "false"
			global_setting.property_value = "true" if setting == property
			global_setting.save
		end
		redirect_to '/clinic' and return
	end
end
