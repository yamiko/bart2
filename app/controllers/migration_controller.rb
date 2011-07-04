class MigrationController < ApplicationController
      def migrate_user
          Migration.get_user_data_from_csv_and_create_user()
      end
end
