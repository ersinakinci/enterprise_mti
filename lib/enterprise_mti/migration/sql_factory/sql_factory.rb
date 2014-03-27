module EnterpriseMti
  module Migration
    module SqlFactory
      
      class SqlFactory
        attr_accessor :superclass_table, :subclass_tables, :container_class_table
      
        def sql_for_up
          setup
          [superclass_table_up, subclass_tables_up].join
        end
      
        def sql_for_down
          setup
          [subclass_tables_down, superclass_table_down].join
        end
        
        protected
        
          attr_accessor :superclass_table_xor_function_name, :superclass_table_xor_constraint_trigger_name
          attr_accessor :superclass_table_container_id_not_null_function_name,
                        :superclass_table_container_id_not_null_constraint_trigger_name
          attr_accessor :subclass_table_valid_foreign_key_function_names, :subclass_table_valid_foreign_key_constraint_trigger_names
          
        private
          
          def setup
            self.superclass_table_xor_function_name                        = "#{superclass_table.to_s.singularize}_types_xor()"
            self.superclass_table_xor_constraint_trigger_name              = "#{superclass_table.to_s.singularize}_types_xor_trig"
            self.superclass_table_container_id_not_null_function_name           = "#{superclass_table}_#{container_class_table.to_s.singularize}_not_null()"
            self.superclass_table_container_id_not_null_constraint_trigger_name = "#{superclass_table}_#{container_class_table.to_s.singularize}_not_null_trig"
            self.subclass_table_valid_foreign_key_function_names           = {}
            self.subclass_table_valid_foreign_key_constraint_trigger_names = {}
            
            subclass_tables.map do |subclass_table|
              subclass_table_valid_foreign_key_function_names[subclass_table.to_sym] =
                "#{subclass_table}_valid_#{superclass_table.to_s.singularize}_id()"
              subclass_table_valid_foreign_key_constraint_trigger_names[subclass_table.to_sym] =
                "#{subclass_table}_valid_#{superclass_table.to_s.singularize}_id_trig"
            end
          end
          
          ## Up methods (superclass) ##
          
          def superclass_table_up
            if self.container_class_table
              [superclass_table_container_mod_up, superclass_table_foreign_keys_up, superclass_table_xor_function_up, superclass_table_xor_constraint_trigger_up]
            else
              [superclass_table_foreign_keys_up, superclass_table_xor_function_up, superclass_table_xor_constraint_trigger_up]
            end
          end
          
          def superclass_table_foreign_keys_up
            subclass_tables.collect do |subclass_table|
              alter_table superclass_table do
                add_column "#{subclass_table.to_s.singularize}_id",
                type: id_type,
                nullable: false,
                unique: true,
                references: { table: subclass_table, column: "id" },
                defer: true
              end
            end
          end
          
          def superclass_table_xor_function_up
            superclass_table_xor_function(superclass_table_xor_function_name, superclass_table, subclass_tables) # DB-specific
          end
          
          def superclass_table_xor_constraint_trigger_up
            create_constraint_trigger(superclass_table_xor_constraint_trigger_name, superclass_table_xor_function_name, superclass_table) # DB-specific
          end
          
          def superclass_table_container_mod_up
            sql = alter_table(superclass_table) { add_column "#{container_class_table.to_s.singularize}_id",
                                                  type: id_type,
                                                  unique: true,
                                                  references: { table: container_class_table, column: "id" },
                                                  defer: true }
                                                  
            sql << superclass_table_container_id_not_null_function(superclass_table_container_id_not_null_function_name,
                                                                   superclass_table)
                                                                   
            sql << create_constraint_trigger(superclass_table_container_id_not_null_constraint_trigger_name,
                                             superclass_table_container_id_not_null_function_name,
                                             superclass_table)
          end
          
          ## Up methods (subclass) ##
          
          def subclass_tables_up
            [ subclass_tables_id_alterations_up,
              subclass_tables_foreign_keys_up,
              subclass_tables_valid_foreign_key_functions_up,
              subclass_tables_valid_foreign_key_constraint_triggers_up ]
          end
          
          def subclass_tables_id_alterations_up
            subclass_tables.collect do |subclass_table|
              alter_table subclass_table do
                add_constraint "id_fkey", type: :foreign_key, column: 'id' do
                  options_parser references: { table: superclass_table, column: "#{subclass_table.to_s.singularize}_id" }, defer: true
                end
              end
            end
          end
          
          def subclass_tables_foreign_keys_up
            subclass_tables.collect do |subclass_table|
              alter_table subclass_table do
                add_column "#{superclass_table.to_s.singularize}_id",
                type: id_type,
                nullable: false,
                unique: true,
                references: { table: superclass_table, column: "id" },
                delete: :cascade,
                defer: true
              end
            end
          end
          
          def subclass_tables_valid_foreign_key_functions_up
            self.subclass_table_valid_foreign_key_function_names.collect do |subclass_table, function|
              subclass_table_valid_foreign_key_function(function, subclass_table, superclass_table)  # DB-specific
            end
          end
          
          def subclass_tables_valid_foreign_key_constraint_triggers_up
            subclass_table_valid_foreign_key_constraint_trigger_names.collect do |subclass_table, constraint_trigger|
              function = subclass_table_valid_foreign_key_function_names[subclass_table]
              create_constraint_trigger(constraint_trigger, function, subclass_table)  # DB-specific
            end
          end
          
          ## Down methods (superclass) ##
          
          def superclass_table_down
            if container_class_table
              [superclass_table_xor_constraint_trigger_down, superclass_table_xor_function_down, superclass_table_foreign_keys_down, superclass_table_container_mod_down]
            else
              [superclass_table_xor_constraint_trigger_down, superclass_table_xor_function_down, superclass_table_foreign_keys_down]
            end
          end
          
          #def superclass_table_xor_constraint_down
          #  alter_table superclass_table do
          #    drop_constraint "#{superclass_table}_xor"
          #  end
          #end
          
          def superclass_table_xor_constraint_trigger_down
            drop_trigger(superclass_table_xor_constraint_trigger_name, superclass_table)
          end
          
          def superclass_table_xor_function_down
            drop_function(superclass_table_xor_function_name)
          end
          
          def superclass_table_foreign_keys_down
            subclass_tables.collect do |subclass_table|
              alter_table superclass_table do
                drop_column("#{subclass_table.to_s.singularize}_id")
              end
            end
          end
          
          def superclass_table_container_mod_down
            sql = drop_trigger(superclass_table_container_id_not_null_constraint_trigger_name, superclass_table)
            sql << drop_function(superclass_table_container_id_not_null_function_name)
            sql << alter_table(superclass_table) { drop_column("#{container_class_table.to_s.singularize}_id") }
          end
          
          ## Down methods (subclass) ##
          
          def subclass_tables_down
            [subclass_tables_valid_foreign_key_constraint_triggers_down, subclass_tables_valid_foreign_key_functions_down, subclass_tables_id_alterations_down]
          end
          
          def subclass_tables_valid_foreign_key_constraint_triggers_down
            subclass_table_valid_foreign_key_constraint_trigger_names.collect do |subclass_table, constraint_trigger|
              drop_trigger(constraint_trigger, subclass_table)
            end
          end
          
          def subclass_tables_valid_foreign_key_functions_down
            subclass_table_valid_foreign_key_function_names.collect do |subclass_table, function|
              drop_function(function)
            end
          end
          
          def subclass_tables_id_alterations_down
            subclass_tables.collect do |subclass_table|
              sql = alter_table(subclass_table){ drop_constraint "id_fkey" }
              sql << alter_table(subclass_table){ drop_column "#{superclass_table.to_s.singularize}_id" }
            end
          end
          
          ## DSL ##
          
          def options_parser(opts={})
            sql = []
            sql.push opts[:type].to_s
            sql.push not_null if opts[:nullable] == false
            sql.push unique if opts[:unique]
            sql.push references table: opts[:references][:table], column: opts[:references][:column] if opts[:references]
            sql.push delete delete: opts[:delete].to_s if opts[:delete]
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
          def drop_function(function);         "DROP FUNCTION #{function};"; end
          def drop_trigger(trigger, table);    "DROP TRIGGER #{trigger} ON #{table};" end
          def not_null;                        "NOT NULL"; end
          def unique;                          "UNIQUE"; end
          def references(opts={});             "REFERENCES #{opts[:table]}(#{opts[:column]})"; end
          def delete(opts={});                 "ON DELETE #{opts[:delete]}"; end
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