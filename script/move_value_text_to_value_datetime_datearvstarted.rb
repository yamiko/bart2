puts "\nStart Time: #{Time.now}"

concept_id = Concept.find_by_name("Date antiretrovirals started").id

obs=Observation.find(:all,
                     :conditions => ["concept_id = ? AND value_text IS NOT NULL",
                                     concept_id])

obs.each do |o|
    o.value_datetime = o.value_text.to_date
    if o.save
        puts "\n Obs #{o.obs_id} >> successfull"
    else
        puts "\n Obs #{o.obs_id} >> failed"
    end
end

puts "\nEnd Time: #{Time.now}"
puts "Completed \n\n"
