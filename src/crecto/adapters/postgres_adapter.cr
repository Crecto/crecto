module Crecto
  module Adapters
    #
    # Adapter module for PostgresSQL
    #
    module Postgres
      extend BaseAdapter

      private def self.update_begin(builder, table_name, fields_values)
        builder << "UPDATE " << table_name << " SET "
        fields_values[:fields].each do |field_value|
          builder << field_value << "=?, "
        end
        builder.back(2)
      end

      private def self.update(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = String.build do |builder|
          update_begin(builder, changeset.instance.class.table_name, fields_values)
          builder << " WHERE (" << changeset.instance.class.primary_key_field << "=?)"
          builder << " RETURNING *"
        end

        execute(conn, position_args(q), fields_values[:values] + [changeset.instance.pkey_value])
      end

      private def self.instance_fields_and_values(query_hash : Hash)
        values = query_hash.values.map do |x|
          if x.is_a?(JSON::Any)
            x.to_json
          elsif x.is_a?(Array)
            x = x.to_json
            x = x.sub(0, "{").sub(x.size - 1, "}")
            elsif x.is_a?(Time)
            # PostgreSQL handles Time natively with timezone awareness
            Crecto::Adapters::BaseAdapter.format_time_for_db(x)
          else
            x.as(DbValue)
          end
        end
        {fields: query_hash.keys, values: values}
      end
    end
  end
end
