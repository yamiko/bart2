class GenericDrugController < ApplicationController

  def name
    @names =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "NH or H (Isoniazid 100mg tablet)"]
    @names += other
    # regimens = regimens.map{|d|
    # concept_name = (d.concept.concept_names.typed("SHORT").first ||	d.concept.concept_names.typed("FULLY_SPECIFIED").first).name
    # if d.regimen_index.blank?
    #	["#{concept_name}", d.concept_id, d.regimen_index.to_i]
		#	else
		#		["#{d.regimen_index} - #{concept_name}", d.concept_id, d.regimen_index.to_i]
		#	end
		#}.sort_by{| r | r[2]}.uniq

    #@names = Drug.find(:all,:conditions =>["name LIKE ?","%" + params[:search_string] + "%"]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end
  
  def add_controllers
    drugs = params[:drug].split(",")
    drugs.each {|drug|
      if drug != ""
        
      end
    }
  end

  def verified_stock
    @delivery_date = params[:observations].first["value_datetime"]
    @drugs = []
    params[:drug_name].each{|drug|
      name = Drug.find_by_name(drug)
      @drugs << [name.name, name.drug_id]
    }
    #raise @drugs.to_yaml
  end
  
  def delivery

    @drugs =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "NH or H (Isoniazid 100mg tablet)"]
    @drugs += other
  end

  def calculate_dispensed
   
    drug_id = Drug.find_by_name(params[:drug]).id
     #raise params[:name].to_yaml
    current_stock = Pharmacy.current_stock_as_from(drug_id , Pharmacy.first_delivery_date(drug_id),params[:start_date].to_date)
     
      expiry = 0
      Pharmacy.currently_expiring_drugs(params[:start_date].to_date, drug_id).each {|stock|
        #raise stock[1].to_yaml
        expiry += stock[1]["delivered_stock"]

      }
      if current_stock < expiry
          expiry = expiry
      elsif current_stock >= expiry
          expiry = current_stock
      end
      # raise expiry.to_yaml
    render :text => expiry
  end

  def create_stock
    params[:drug].each{ |delivered|

      delivery_date = params['delivery date'].to_date
      drug_id = Drug.find_by_name(delivered[:name]).id



      expiry_date = delivered["#{delivered[:name]}"]['expiry_date'].to_date
    
      number_of_tins = delivered["#{delivered[:name]}"]['tins'].to_f
      number_of_pills_per_tin = delivered["#{delivered[:name]}"]['pills'].to_f
      number_of_pills = (number_of_tins * number_of_pills_per_tin)
      barcode = params[:identifier]
      Pharmacy.new_delivery(drug_id,number_of_pills,delivery_date,nil,expiry_date,barcode)
    }
    #add a notice
    #flash[:notice] = "#{params[:drug_name]} successfully entered"
    redirect_to "/clinic"   # /management"
  end

  def edit_stock
    if request.method == :post
      obs = params[:observations]
      edit_reason = obs[0]['value_coded_or_text']
      encounter_datetime = obs[1]['value_datetime']
      drug_id = Drug.find_by_name(params[:drug_name]).id
      pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
      date = encounter_datetime || Date.today 

      if edit_reason == 'Receipts from other clinics'
        expiry_date = obs[2]['value_datetime'].to_date
        Pharmacy.new_delivery(drug_id,pills,date,nil,expiry_date,edit_reason)
      else
        Pharmacy.drug_dispensed_stock_adjustment(drug_id,pills,date,edit_reason)
      end
      #flash[:notice] = "#{params[:drug_name]} successfully edited"
      redirect_to "/clinic"   # /management"
    else 
      @drugs =  Regimen.find_by_sql(
        "select distinct(d.name) from regimen r
                      inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
                      inner join drug d on d.drug_id = rd.drug_inventory_id
                      where r.regimen_index is not null
                      and r.regimen_index != 0
        ").collect{|drug| drug.name}.compact.sort.uniq rescue []
      other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "NH or H (Isoniazid 100mg tablet)"]
      @drugs += other
    end
  end

  def set_quantity
    
  end

  def verification
    obs = params[:observations]
    edit_reason = obs[0]['value_coded_or_text']
    encounter_datetime = obs[0]['value_datetime']
    drug_id = Drug.find_by_name(params[:drug_name]).id
    pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
    date = encounter_datetime || Date.today
    Pharmacy.verified_stock(drug_id,date,pills) 
    redirect_to "/clinic"   # /management"
  end

  def stoke_movement
    obs = params[:observations]
    params[:start_date] =  obs[0]['value_datetime']
    params[:end_date] =  obs[1]['value_datetime']
    params[:drug_id] = Drug.find_by_name(params[:drug_name]).id

    @drug = Drug.find(params[:drug_id]).name
    render :layout => false
  end

  def stock_report
    @logo = CoreService.get_global_property_value('logo') rescue ''
    @current_location_name = Location.current_health_center.name rescue ''
    @start_date = params[:start_date].to_date rescue params[:delivery_date].to_date
    @end_date = params[:end_date].to_date rescue params[:delivery_date].to_date

    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)
    #TODO

    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id
    new_deliveries = Pharmacy.active.find(:all,
      :conditions =>["pharmacy_encounter_type=?",encounter_type],
      :order => "encounter_date DESC,date_created DESC")

   
    current_stock = {}
    new_deliveries.each{|delivery|
      current_stock[delivery.drug_id] = delivery if current_stock[delivery.drug_id].blank?
    }

    @stock = {}
    
    current_stock.each{|delivery_id , delivery|
      first_date = Pharmacy.active.find(:first,:conditions =>["drug_id =?",
          delivery.drug_id],:order => "encounter_date").encounter_date.to_date rescue nil
      next if first_date.blank?
      next if first_date > @end_date

      start_date = @start_date
      end_date = @end_date
                   
      drug = Drug.find(delivery.drug_id)
      drug_name = drug.name

      #Pharmacy.verify_stock_count(drug.id,start_date,end_date)
      @stock[drug_name] = {"confirmed_closing" => 0,"dispensed" => 0,"current_stock" => 0 ,
        "confirmed_opening" => 0, "start_date" => start_date , "end_date" => end_date,
        "relocated" => 0, "receipts" => 0,"expected" => 0 ,"drug_id" => drug.id }
      @stock[drug_name]["dispensed"] = Pharmacy.dispensed_drugs_since(drug.id,start_date,end_date)
      @stock[drug_name]["confirmed_opening"] = Pharmacy.verify_stock_count(drug.id,start_date,start_date)
      @stock[drug_name]["confirmed_closing"] = Pharmacy.verify_closing_stock_count(drug.id,start_date,end_date)
      @stock[drug_name]["current_stock"] = Pharmacy.current_stock_as_from(drug.id,start_date,end_date)
      @stock[drug_name]["relocated"] = Pharmacy.relocated(drug.id,start_date,end_date)
      @stock[drug_name]["receipts"] = Pharmacy.receipts(drug.id,start_date,end_date)
      @stock[drug_name]["expected"] = Pharmacy.expected(drug.id,start_date,end_date)
    }    

  end

  def current_stock
    drug = Drug.find_by_name(params[:drug])
    start_date = Date.today
    end_date =  start_date + 30.days
    expected = Pharmacy.expected(drug.id, start_date,end_date)
    render :text => (expected.to_json)
  end

  def stock_chart
    encounter_type = PharmacyEncounterType.find_by_name("Tins currently in stock").id
    #new_deliveries = Pharmacy.active.find(:first,
    # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], params[:end_date] ],
    #  :order => "encounter_date DESC,date_created DESC")
    
    @stocks = []
    current_stock = {}
    month_difference = (params[:end_date].to_date.year * 12 + params[:end_date].to_date.month) - (params[:start_date].to_date.year * 12 + params[:start_date].to_date.month)
    n = params[:end_date].to_date
    # raise Pharmacy.expected(params[:drug_id], params[:start_date], params[:end_date]).to_yaml
    if month_difference <= 1
      while n >= params[:start_date].to_date
        new_deliveries = Pharmacy.expected(params[:drug_id], params[:start_date], n)
        # new_deliveries = Pharmacy.active.find(:first,
        # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], n ],
        # :order => "encounter_date DESC,date_created DESC")
        current_stock[n] = (new_deliveries / 60).round rescue 0
        n = n - 1.days
      end
    elsif month_difference > 1 and month_difference <= 12
      while n >= params[:start_date].to_date
        new_deliveries = Pharmacy.expected(params[:drug_id], params[:start_date], n)
        # new_deliveries = Pharmacy.active.find(:first,
        # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], n ],
        # :order => "encounter_date DESC,date_created DESC")
        current_stock[n] = (new_deliveries / 60).round rescue 0
        n = n - 1.months

      end
    else
      while n >= params[:start_date].to_date
        new_deliveries = Pharmacy.expected(params[:drug_id], params[:start_date], n)
        #new_deliveries = Pharmacy.active.find(:first,
        #:conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], n ],
        #:order => "encounter_date DESC,date_created DESC")
        current_stock[n] = (new_deliveries / 60).round rescue 0
        n = n - 1.years
      end
    end
    
    #new_deliveries.each{|delivery|
    #  current_stock[delivery.encounter_date] = (delivery.value_numeric / 60 ).round #if current_stock[delivery.drug_id].blank?
    # }

    (current_stock || {}).sort{|a,b|a[0].to_date <=> b[0].to_date}.each do |date,weight|
      @stocks << [date.to_date.strftime('%d.%b.%y') , weight]
    end
    @stocks = @stocks.to_json
    render :partial => "stoke_chart" and return
  end

  def date_select
    @goto = params[:goto]
    @goto = 'stock_report' if @goto.blank?
    @drugs =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "NH or H (Isoniazid 100mg tablet)"]
    @drugs += other
  end

  def stock_movement_menu
    
  end

  def print_barcode
    if request.post?
      print_and_redirect("/drug/print?drug_id=#{params[:drug_id]}&quantity=#{params[:pill_count]}", "/drug/print_barcode")
    else
      @drugs = Drug.find(:all,:conditions =>["name IS NOT NULL"])
    end
  end
  
  def print
    pill_count = params[:quantity]
    drug = Drug.find(params[:drug_id])
    drug_name = drug.name
    drug_name1=""
    drug_name2=""
    drug_quantity = pill_count
    drug_barcode = "#{drug.id}-#{drug_quantity}"
    drug_string_length =drug_name.length

    if drug_name.length > 27
      drug_name1 = drug_name[0..25]
      drug_name2 = drug_name[26..-1]
    end

    if drug_string_length <= 27
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 80, 0, 2, 2, 2,false)
      label.draw_barcode(40, 130, 0, 1, 5, 15, 120,true, "#{drug_barcode}")
    else
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name1}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("#{drug_name2}", 40, 80, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 130, 0, 2, 2, 2,false)
      label.draw_barcode(40, 180, 0, 1, 5, 15, 100,true, "#{drug_barcode}")
    end
    send_data(label.print(1),:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{drug_barcode}.lbl", :disposition => "inline")
  end

  def expiring
    @logo = CoreService.get_global_property_value('logo') rescue ''
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @expiring_drugs = Pharmacy.expiring_drugs(@start_date,@end_date)
    render :layout => "menu"
  end
  
  def removed_from_shelves
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @drugs_removed = Pharmacy.removed_from_shelves(@start_date,@end_date)
    render :layout => "menu"
  end

  def available_name    
    ids = Pharmacy.active.find(:all).collect{|p|p.drug_id} rescue []
    @names = Drug.find(:all,:conditions =>["name LIKE ? AND drug_id IN (?)","%" + 
          params[:search_string] + "%", ids]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def stock_report_edit
    if request.post?   
      unless params[:obs].blank?
        params[:obs].each{|obs|
          tins = obs[1].to_i
          pills = tins * 60
          Pharmacy.verified_stock(obs[0], params[:delivery_date],pills)
          #raise Drug.find(obs[0]).to_yaml
        }
      else
        obs = params[:observations]
        edit_reason = obs[0]['value_coded_or_text'] rescue nil
        encounter_datetime = params[:encounter_date]
        drug_id = params[:drug_id]
        pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
        date = encounter_datetime || Date.today

        unless edit_reason.blank?
          Pharmacy.drug_dispensed_stock_adjustment(drug_id,pills,date,edit_reason)
        else
          Pharmacy.verified_stock(drug_id,date,pills)
        end
      end
      redirect_to :action => 'stock_report', :start_date => params[:start_date],                                  
        :end_date => params[:end_date], :delivery_date => params[:delivery_date]
    else
      @edit_reason = params[:edit_reason]
      @drug_id = params[:drug_id]
      @encounter_date = params[:date]
      @max_date = params[:max_date]
      @start_date = params[:start_date]
      @end_date = params[:end_date]
    end
  end

end
