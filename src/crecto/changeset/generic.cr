module Crecto
  module Changeset(T)
    class GenericChangeset
      # :nodoc:
      property instance : Crecto::Model
      # :nodoc:
      property action : Symbol?
      # :nodoc:
      property errors = [] of Hash(Symbol, String)
      # :nodoc:
      property changes = [] of Hash(Symbol, DbValue | ArrayDbValue)
      # :nodoc:
      property source : Hash(Symbol, DbValue)? | Hash(Symbol, ArrayDbValue)?
      
      private property valid = true

      def self.from_changeset(changeset)
        new(
          changeset.instance,
          changeset.action,
          changeset.errors,
          changeset.changes,
          changeset.valid?
        )
      end

      def initialize(@instance, @action, @errors, @changes, @valid)
      end

      def valid?
        @valid
      end
    end
  end
end
