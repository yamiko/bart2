class PrescriptionsController < GenericPrescriptionsController
  def new_prescription
    @partial_name = 'drug_set'
    @partial_name = params[:screen] unless params[:screen].blank?
    @drugs = Drug.find(:all,:limit => 100)
    @drug_sets = {}
    Drug.find(:all,:limit => 5,:order => "name DESC").each do |d|
      @drug_sets[d.name] = { :duration => '30',:frequency => "OD",:dose => 2, :unit => 2 }
    end
    render :layout => false
  end

  def search_for_drugs
    drugs = Drug.find(:all, :conditions => ["name LIKE (?)","%#{params[:searh_str]}%"])
    render :text => "<li>" + drugs.map{|d| d.name } .join("</li><li>") + "</li>"
  end

end
