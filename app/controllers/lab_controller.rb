class LabController < ApplicationController
  def results
    @results = []
    @patient = Patient.find(params[:id])
    (Lab.results(@patient) || []).map do | short_name , test_name , range , value , test_date |
      @results << [short_name.gsub('_',' '),"/lab/view?test=#{short_name}&patient_id=#{@patient.id}"]
    end
    render :layout => 'menu'
  end

end
