module Crecto
  module Schema
    module BuildFromSQL
      def from_sql(hash : Nil)
        nil
      end

      def from_sql(hash)
        object = {{@type.id}}.new

        {% for prop in @type.instance_vars %}
          if hash.has_key?("{{prop}}")
            object.{{prop}} = hash["{{prop}}"].as({{prop.type}})
          end
        {% end %}
        
        object.initial_values = object.to_query_hash
        object
      end

    end
  end
end