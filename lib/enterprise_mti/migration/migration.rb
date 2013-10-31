require_relative 'sql_factory'

module EnterpriseMti
  module Migration
    
    def enterprise_mti_run(opts={})
      if opts[:superclass_table] && opts[:subclass_tables] && opts[:direction]

        case Rails.configuration.database_configuration[Rails.env]['adapter']
        when 'postgresql'
          sql_factory = SqlFactory::PostgresSqlFactory.new
        end
    
        sql_factory.superclass_table = opts[:superclass_table]
        sql_factory.subclass_tables = opts[:subclass_tables]
    
        sql = sql_factory.sql_for_up if opts[:direction] == :up
        sql = sql_factory.sql_for_down if opts[:direction] == :down
        
        execute sql
      end
    end
    
    def enterprise_mti_up(opts={})
      enterprise_mti_run opts.merge!(direction: :up)
    end

    def enterprise_mti_down(opts={})
      enterprise_mti_run opts.merge!(direction: :down)
    end
  end
end

ActiveRecord::Migration.send :include, EnterpriseMti::Migration