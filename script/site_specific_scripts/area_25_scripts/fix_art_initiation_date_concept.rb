
def start

  concept = Concept.find_by_name('Date antiretrovirals started').concept_id
  change_concept = Concept.find_by_name('ART initiation date').concept_id

  Observation.update_all({:concept_id => concept}, ["concept_id = ?", change_concept])


end

start