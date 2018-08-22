module Crecto
  module Adapters
    #
    # Adapter module for PostgresSQL
    #
    module Postgres
      extend BaseAdapter

      private def self.update_begin(builder, table_name, fields_values)
        builder << "UPDATE " << table_name << " SET ("
        builder << fields_values[:fields] << ')'
        builder << " = ("
        fields_values[:values].size.times do
          builder << "?, "
        end
        builder.back(2)
        builder << ')'
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
            x
          else
            x.as(DbValue)
          end
        end
        {fields: query_hash.keys.join(", "), values: values}
      end
    end
  end
end
