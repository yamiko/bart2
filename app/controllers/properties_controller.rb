class PropertiesController < GenericPropertiesController
	def export_cohort_data
		 if request.post? and not params[:export_cohort_data].blank?
			 session["export.cohort.data"] = params[:export_cohort_data]
      redirect_to '/clinic' and return
    end
	end

end
