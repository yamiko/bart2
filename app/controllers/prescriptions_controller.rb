class PrescriptionsController < GenericPrescriptionsController
  def new_prescription
    @partial_name = 'drug_set'
    @partial_name = params[:screen] unless params[:screen].blank?
    @drugs = Drug.find(:all,:limit => 100)
    @drug_sets = {}
    drug_names = ['Quinine (600mg)','Azithromycin (250mg tablet)','Albendazole (400mg tablet)','Fefol (450 mg)','Doxycycline (200mg tablet)']
    drug_set_attr = [
      ['OD', 1, 7],
      ['OD', 1, 7],
      ['BD', 2, 2],
      ['OD', 1, 30],
      ['OD', 1, 7]
    ]

    Drug.find(:all,:limit => 5,:order => "name DESC",
      :conditions =>["name IN(?)",drug_names]).each_with_index do |d , i|
      @drug_sets[d.name] = { :duration => drug_set_attr[i][2],
        :frequency => drug_set_attr[i][0],:dose => drug_set_attr[i][1], :unit => 2,
        :display_name => "#{drug_names[i]} (#{drug_set_attr[i][0]}) #{drug_set_attr[i][2]} day(s)" }
    end
    render :layout => false
  end

  def search_for_drugs
    drugs = {}
    Drug.find(:all, :conditions => ["name LIKE (?)",
      "#{params[:search_str]}%"],:order => 'name',:limit => 20).map do |drug|
      drugs[drug.id] = { :name => drug.name,:dose_strength =>drug.dose_strength || 1, :unit => drug.units }
    end
    render :text => drugs.to_json
  end

end
