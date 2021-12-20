module Crecto
  # Multi is used for grouping multiple Repo operations into a single transaction
  #
  # Operations will be executed in the order they were added
  #
  # If a Multi contains operations that accept a Changeset, they will be checked before starting the transaction.
  # If any changesets have errors, the transaction will never be started.
  #
  class Multi
    # :nodoc:
    property errors = Array(Hash(String, String)).new
    # :nodoc:
    record Insert, instance : Crecto::Model
    # :nodoc:
    record Delete, instance : Crecto::Model
    # :nodoc:
    record DeleteAll, queryable : Crecto::Model.class, query : Crecto::Repo::Query
    # :nodoc:
    record Update, instance : Crecto::Model

    # :nodoc:
    alias UpdateHash = Hash(String, PkeyValue) |
                       Hash(String, DbValue) |
                       Hash(String, Array(DbValue)) |
                       Hash(String, Array(PkeyValue)) |
                       Hash(String, Array(Int32)) |
                       Hash(String, Array(Int64)) |
                       Hash(String, Array(String)) |
                       Hash(String, Int32 | String) |
                       Hash(String, Int32) |
                       Hash(String, Int64) |
                       Hash(String, String) |
                       Hash(String, Int32 | Int64 | String | Nil)

    # :nodoc:
    record UpdateAll, queryable : Crecto::Model.class, query : Crecto::Repo::Query, update_hash : UpdateHash
    # :nodoc:
    property operations = Array(Insert | Delete | DeleteAll | Update | UpdateAll).new

    {% for type in %w[insert delete update] %}
      def {{type.id}}(queryable_instance : Crecto::Model)
        operations.push({{type.camelcase.id}}.new(queryable_instance))
      end

      def {{type.id}}(changeset : Crecto::Changeset::Changeset)
        {{type.id}}(changeset.instance)
      end
    {% end %}

    def delete_all(queryable, query = Crecto::Repo::Query.new)
      operations.push(DeleteAll.new(queryable, query))
    end

    def update_all(queryable, query, update_hash : UpdateHash)
      operations.push(UpdateAll.new(queryable, query, update_hash))
    end

    def update_all(queryable, query, update_tuple : NamedTuple)
      update_all(queryable, query, update_tuple.to_h)
    end

    def changesets_valid?
      operations.each do |operation|
        next unless operation.is_a?(Insert | Delete | Update)

        changeset = operation.instance.get_changeset
        next if changeset.valid?
        @errors = changeset.errors.tap do |errors|
          errors.first[:queryable] = operation.instance.class.to_s
          errors.first[:failed_operation] = operation.class.to_s
        end
        return false
      end

      return true
    end
  end
end
