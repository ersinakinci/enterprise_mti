module EnterpriseMti
  module Migration
    module SqlFactory
      
      class PostgresSqlFactory < SqlFactory
        def integer
          "INTEGER"
        end
        
        def id_type
          "BIGINT"
        end
      end
    end
  end
end