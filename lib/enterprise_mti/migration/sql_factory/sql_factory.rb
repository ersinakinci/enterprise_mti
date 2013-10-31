module EnterpriseMti
  module Migration
    module SqlFactory
      
      class SqlFactory
        attr_accessor :superclass_table, :subclass_tables
      
        def sql_for_up
          [superclass_table_up, subclass_tables_up].join
        end
      
        def sql_for_down
          [subclass_tables_down, superclass_table_down].join
        end
      
        ## Up methods (superclass) ##
      
        def superclass_table_up
          [superclass_table_foreign_keys_up, superclass_table_xor_constraint_up]
        end
      
        def superclass_table_foreign_keys_up
          subclass_tables.map { |subclass_table|
            alter_table superclass_table do
              add_column "#{subclass_table}_id",
              type: id_type,
              nullable: false,
              unique: true,
              references: { table: subclass_table, column: "id" },
              defer: true
            end
          }
        end
        
        def superclass_table_xor_constraint_up
          alter_table superclass_table do
            add_constraint "#{superclass_table}_xor", type: :check do
              subclass_tables.map { |subclass_table|
                "(#{subclass_table}_id IS #{not_null})::#{integer}"
              }.join(' + ') << ' = 1'
            end
          end
        end
        
        ## Up methods (subclass) ##
        
        def subclass_tables_up
          subclass_tables_id_alterations_up
        end
        
        def subclass_tables_id_alterations_up
          subclass_tables.map { |subclass_table|
            alter_table subclass_table do
              add_constraint "id_fkey", type: :foreign_key, column: 'id' do
                options_parser references: { table: superclass_table, column: "#{subclass_table}_id" }, defer: true
              end
            end
          }
        end
      
        ## Down methods (superclass) ##
      
        def superclass_table_down
          [superclass_table_xor_constraint_down, superclass_table_foreign_keys_down]
        end
      
        def superclass_table_xor_constraint_down
          alter_table superclass_table do
            drop_constraint "#{superclass_table}_xor"
          end
        end
      
        def superclass_table_foreign_keys_down
          subclass_tables.map do |subclass_table|
            alter_table superclass_table do
              drop_column("#{subclass_table}_id")
            end
          end
        end
        
        ## Down methods (subclass) ##
        
        def subclass_tables_down
          subclass_tables_id_alterations_down
        end
        
        def subclass_tables_id_alterations_down
          subclass_tables.map do |subclass_table|
            alter_table subclass_table do
              drop_constraint 'id_fkey'
            end
          end
        end
      
        ## DSL ##
      
        def options_parser(opts={})
          sql = []
          sql.push opts[:type]
          sql.push not_null if opts[:nullable] == false
          sql.push unique if opts[:unique]
          sql.push references table: opts[:references][:table], column: opts[:references][:column] if opts[:references]
          sql.push defer if opts[:defer]
          sql.join(' ')
        end
        def alter_table(table);              "ALTER TABLE #{table} #{yield};"; end
        def add_column(column, opts={})
          "ADD COLUMN #{column} #{options_parser opts}"
        end
        def alter_column(column, opts={})
          "ALTER COLUMN #{column} SET #{options_parser opts}"
        end
        def drop_column(column);             "DROP COLUMN #{column}"; end
        def not_null;                        "NOT NULL"; end
        def unique;                          "UNIQUE"; end
        def references(opts={});             "REFERENCES #{opts[:table]}(#{opts[:column]})"; end
        def add_constraint(name, opts={})
          case opts[:type]
          when :check
            type = 'CHECK ('
            suffix = ')'
          when :foreign_key
            type = "FOREIGN KEY(#{opts[:column]})"
          end
          "ADD CONSTRAINT #{name} #{type} #{yield} #{suffix}"
        end
        def drop_constraint(name);           "DROP CONSTRAINT #{name}"; end
        def defer;                           "DEFERRABLE INITIALLY DEFERRED"; end
      end
    end
  end
end