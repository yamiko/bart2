class Lab < ActiveRecord::Base
  set_table_name "map_lab_panel"

  def self.results(patient)
    patient_ids = patient.id_identifiers
    results = self.find_by_sql(["
SELECT * FROM Lab_Sample s
INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
INNER JOIN codes_TestType c ON p.testtype = c.testtype
INNER JOIN map_lab_panel m ON c.panel_id = m.rec_id
WHERE s.patientid IN (?)
AND s.deleteyn = 0
AND s.attribute = 'pass'
GROUP BY short_name ORDER BY m.short_name",patient_ids
    ]).collect do | result |
      [
        result.short_name,
        result.TestName,
        result.Range,
        result.TESTVALUE,
        result.TESTDATE
      ]
    end

    return if results.blank?
    results
  end

end
