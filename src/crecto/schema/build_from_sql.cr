module Crecto
  module Schema
    module BuildFromSQL
      def from_sql(hash)
        return nil if hash.nil?
        object = {{@type.id}}.new

        {% for prop in @type.instance_vars %}
          {% if prop.stringify != "created_at" && prop.stringify != "updated_at" %}
            if hash.has_key?("{{prop}}")
              object.{{prop}} = hash["{{prop}}"].as({{prop.type}})
            end
          {% end %}
        {% end %}

        # if hash.has_key?("created_at")
        #   created = hash["created_at"].as(Time)
        #   object.created_at = created.to_s("%s%L").to_i64
        # end

        # if hash.has_key?("updated_at")
        #   updated = hash["updated_at"].as(Time)
        #   object.updated_at = updated.to_s("%s%L").to_i64
        # end
        object
      end
    end
  end
end