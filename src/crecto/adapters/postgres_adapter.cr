module Crecto
  module Adapters
    #
    # Adapter module for PostgresSQL
    #
    module Postgres
      extend BaseAdapter

      private def self.update_begin(table_name, fields_values)
        q = ["UPDATE"]
        q.push "#{table_name}"
        q.push "SET"
        q.push "(#{fields_values[:fields]})"
        q.push "="
        q.push "(#{(1..fields_values[:values].size).map { "?" }.join(", ")})"
      end

      private def self.update(conn, changeset)
        fields_values = instance_fields_and_values(changeset.instance)

        q = update_begin(changeset.instance.class.table_name, fields_values)
        q.push "WHERE"
        q.push "#{changeset.instance.class.primary_key_field}='#{changeset.instance.pkey_value}'"
        q.push "RETURNING *"

        execute(conn, position_args(q.join(" ")), fields_values[:values])
      end

      private def self.instance_fields_and_values(query_hash : Hash)
        values = query_hash.values.map { |x| x.is_a?(JSON::Any) ? x.to_json : x.as(DbValue) }
        {fields: query_hash.keys.join(", "), values: values}
      end
    end
  end
end
