require Rails.root.join('db', 'migrate', '20131029213145_create_superthings.rb')
require Rails.root.join('db', 'migrate', '20131029213154_create_subthing_ones.rb')
require Rails.root.join('db', 'migrate', '20131029213203_create_subthing_twos.rb')
require Rails.root.join('db', 'migrate', '20131029213251_start_enterprise_mti.rb')
require Rails.root.join('db', 'migrate', '20131031131410_create_containers.rb')

module MigrationHelpers
  
  def migrate_all
    ActiveRecord::Base.transaction do
      CreateSuperthings.migrate :up
      CreateSubthingOnes.migrate :up
      CreateSubthingTwos.migrate :up
      StartEnterpriseMti.migrate :up
      CreateContainers.migrate :up
    end
  end
  
  def rollback_all
    ActiveRecord::Base.transaction do
      CreateContainers.migrate :down
      StartEnterpriseMti.migrate :down
      CreateSubthingTwos.migrate :down
      CreateSubthingOnes.migrate :down
      CreateSuperthings.migrate :down
    end
  end
  
  def columns(table)
    ActiveRecord::Base.connection.execute(<<-SQL
      select * from information_schema.columns where table_name='#{table}';
    SQL
    ).to_a.collect { |row| row['column_name'] }
  end
  
  def constraints(table)
    ActiveRecord::Base.connection.execute(<<-SQL
      select * from information_schema.constraint_column_usage where table_name='#{table}';
    SQL
    ).to_a.collect { |row| row['constraint_name'] }
  end
end