module Crecto
  # Your data models should extend `Crecto::Model`:
  #
  # `class User < Crecto::Model`
  #  -or-
  #
  # ```
  # class User
  #   include Crecto::Schema
  #   extend Crecto::Changeset(User)
  # end
  # ```
  abstract class Model
    macro inherited
      include Crecto::Schema
      include Crecto::Schema::HasMany
      include Crecto::Schema::HasOne
      include Crecto::Schema::BelongsTo
      extend Crecto::Changeset({{@type}})

      CRECTO_DESTROY_ASSOCIATIONS = Array(String).new
      CRECTO_NULLIFY_ASSOCIATIONS = Array(String).new
      CRECTO_MODEL_FIELDS = [] of NamedTuple(name: String, type: String)

      def self.use_primary_key?
        CRECTO_USE_PRIMARY_KEY
      end

      def self.fields
        CRECTO_MODEL_FIELDS
      end

      def self.destroy_associations
        CRECTO_DESTROY_ASSOCIATIONS
      end

      def self.nullify_associations
        CRECTO_NULLIFY_ASSOCIATIONS
      end

      def self.add_destroy_association(a)
        CRECTO_DESTROY_ASSOCIATIONS << a
      end

      def self.add_nullify_association(a)
        CRECTO_NULLIFY_ASSOCIATIONS << a
      end

      # Class variables
      @@changeset_fields = [] of String
      @@initial_values = {} of String => DbValue

      # Instance properties
      @[JSON::Field(ignore: true)]
      property initial_values : Hash(String, DbValue)?

      def initialize
      end

      # Return the primary key field as a String
      def self.primary_key_field
        CRECTO_PRIMARY_KEY_FIELD
      end

      def self.created_at_field
        CRECTO_CREATED_AT_FIELD
      end

      def self.updated_at_field
        CRECTO_UPDATED_AT_FIELD
      end

      # Class method to get the `changeset_fields`
      def self.changeset_fields
        @@changeset_fields
      end

      # Class method to get the table name
      def self.table_name
        @@table_name
      end

      def get_changeset
        self.class.changeset(self)
      end

      # Empty association methods
      # Implementations are in the setup_association macro
      def self.klass_for_association(association : String | Symbol)
      end

      def self.foreign_key_for_association(association : String | Symbol) : String?
      end

      def self.foreign_key_for_association(klass : Crecto::Model.class)
      end

      def self.foreign_key_value_for_association(association : String | Symbol, item)
      end

      def self.set_value_for_association(association : String | Symbol, item, items)
      end

      def self.association_type_for_association(association : String | Symbol)
      end

      def self.through_key_for_association(association : String | Symbol) : String?
      end

      # Class methods for mass assignment
      def self.cast(**attributes)
        new.tap { |m| m.cast(**attributes) }
      end

      def self.cast(attributes : NamedTuple, whitelist : Tuple = attributes.keys)
        new.tap { |m| m.cast(attributes, whitelist) }
      end

      def self.cast(attributes : Hash(String, T), whitelist : Array(String | Symbol) = attributes.keys) forall T
        new.tap { |m| m.cast(attributes, whitelist) }
      end

      # Class methods for compile-time type safe mass assignment
      def self.cast!(**attributes : **T) forall T
        new.tap { |m| m.cast!(**attributes) }
      end

      def self.cast!(attributes : NamedTuple)
        cast!(**attributes)
      end

      # Empty instance methods for mass assignment
      # Implementations are in the Schema.setup macro
      def cast(**attributes : **T) forall T
      end

      def cast(attributes : NamedTuple, whitelist : Tuple = attributes.keys)
      end

      def cast(attributes : Hash(String | Symbol, T), whitelist : Array(String | Symbol) = attributes.keys) forall T
      end

      # Instance method for compile-time type safe mass assignment
      def cast!(**attributes : **T) forall T
        \{% for key in T.keys %}
           self.\{{ key }} = attributes[\{{ key.stringify }}]
        \{% end %}
      end

      def cast!(attributes : NamedTuple)
        cast!(**attributes)
      end
    end
  end
end
