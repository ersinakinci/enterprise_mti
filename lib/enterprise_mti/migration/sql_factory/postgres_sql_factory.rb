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
        
        def subclass_table_valid_foreign_key_function(function, subclass_table, superclass_table)
          subclass_table_fk = "#{superclass_table.to_s.singularize}_id"
          superclass_table_fk = "#{subclass_table.to_s.singularize}_id"
          "CREATE FUNCTION #{function} RETURNS trigger AS $$
            DECLARE
              new_record #{superclass_table}%ROWTYPE;
            BEGIN
              SELECT * INTO new_record FROM #{superclass_table} WHERE id = NEW.#{subclass_table_fk};
              IF new_record.#{superclass_table_fk} != NEW.id THEN
                RAISE EXCEPTION 'corresponding #{superclass_table}(#{superclass_table_fk}) != new #{subclass_table_fk}(id) (% != %)', #{superclass_table}.#{superclass_table_fk}, NEW.id;
              END IF;
              RETURN NEW;
            END;
          $$ LANGUAGE plpgsql;"
        end 
        
        def subclass_table_valid_foreign_key_constraint_trigger(constraint_trigger, function, subclass_table)
          "CREATE CONSTRAINT TRIGGER #{constraint_trigger}
             AFTER INSERT OR UPDATE ON #{subclass_table}
             DEFERRABLE INITIALLY DEFERRED
             FOR EACH ROW
             EXECUTE PROCEDURE #{function};"
        end
        
        def superclass_table_xor_function(xor_func, superclass_table, subclass_tables)
          superclass_table = superclass_table.to_s
          
          "CREATE FUNCTION #{xor_func} RETURNS TRIGGER AS $$
             DECLARE
               xor_val integer := -50;
               new_row #{superclass_table}%ROWTYPE;
             BEGIN
               SELECT * INTO new_row FROM #{superclass_table} WHERE id = NEW.id;
               xor_val =" + superclass_table_xor_addition("new_row", subclass_tables) + "
               IF xor_val != 1 THEN
                 RAISE EXCEPTION 'failed #{xor_func}, %(id) = %', TG_TABLE_NAME, NEW.id;
               END IF;
               RETURN NEW;
             END;
           $$ LANGUAGE plpgsql;"
        end
          
        def superclass_table_xor_constraint_trigger(constraint_trigger, function, superclass_table)
          superclass_table = superclass_table.to_s
          
          "CREATE CONSTRAINT TRIGGER #{constraint_trigger}
             AFTER INSERT OR UPDATE ON #{superclass_table}
             DEFERRABLE INITIALLY DEFERRED
             FOR EACH ROW
             EXECUTE PROCEDURE #{function};"
        end
        
        private
        
          def superclass_table_xor_addition(new_row, subclass_tables)
            subclass_tables.collect { |subclass_table|
              "(#{new_row}.#{subclass_table.to_s.singularize}_id IS NOT NULL)::INTEGER + "
            }.join()[0..-4] + ";"
          end
      end
    end
  end
end