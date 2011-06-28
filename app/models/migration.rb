class Migration

  def create_person_from_csv(csv_url)

      person_id  = 0
      patient_id  = 1
      arv_number = 2
      national_id = 3
      first_name  = 4
      last_name   = 5
      sex = 6
      birth_date  = 7
      birthdate_estimated = 8
      occupation = 9
      cell_phone_number  = 10
      home_phone_number  = 11
      office_phone_number =12
      physical_adress =13
      landmark  = 14
      city_village = 15
      traditional_authority = 16
      patient_voided = 17
      creator = 18
      void_reason = 19
      change_by = 20
      date_created = 21

      person = {}

      person = { "person"=>{ "occupation"=>"",
                        "age_estimate"=>"",
                        "cell_phone_number"=>"",
                        "birth_month"=>"",
                        "addresses"=>{ "address2"=>"",
                                       "city_village"=>"",
                                       "county_district"=>""
                                      },
                        "gender"=>"",
                        "patient_id"=>"",
                        "birth_day"=>"",
                        "names"=>{"family_name"=>"",
                                  "given_name"=>""
                                 },
                        "birth_year"=>""
                       },
            "relation"=>"",
            "identifier"=>""
           }

      i = 0
      FasterCSV.foreach("#{csv_url}", :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|

        person["person"]["occupation"] = row[occupation].to_s rescue nil
        person["person"]["age_estimate"] = row[birthdate_estimated].to_s rescue nil
        person["person"]["cell_phone_number"] = row[cell_phone_number].to_s rescue nil

        person["person"]["birth_month"] = row[birth_date].to_date.month rescue nil
        person["person"]["birth_year"] = row[birth_date].to_date.year rescue nil
        person["person"]["birth_day"] = row[birth_date].to_date.day rescue nil

        person["person"]["addresses"]["address2"] = row[landmark].to_s rescue nil
        person["person"]["addresses"]["city_village"] = row[city_village].to_s rescue nil
        person["person"]["addresses"]["county_district"] = row[traditional_authority].to_s rescue nil

        person["person"]["gender"] = row[sex].to_s rescue nil
        person["person"]["patient_id"] = row[patient_id].to_s rescue nil

        person["person"]["names"]["family_name"] = row[last_name].to_s rescue nil
        person["person"]["names"]["given_name"] = row[first_name].to_s rescue nil

        person_arv_number  = row[arv_number].to_s rescue nil
        person_national_id = row[national_id].to_s rescue nil

        Person.migrated_datetime = row[date_created].to_datetime.strftime("%Y-%m-%d %H:%M:%S").to_s rescue nil
        Person.migrated_creator  = row[creator].to_s
        person = Person.create_from_migrated_data(person["person"])
      end
  end
end
