module Crecto
  module Schema
    module Associations
      macro setup_associations
        # :nodoc:
        CRECTO_ASSOCIATIONS = Array(
          NamedTuple(
            association_type: String,
            key: String,
            this_klass: Crecto::Model.class,
            klass: Crecto::Model.class,
            foreign_key: String,
            foreign_key_value: Proc(Crecto::Model, PkeyValue),
            set_association: Proc(Crecto::Model, (Array(Crecto::Model) | Crecto::Model), Nil),
            through: String?
          )
        ).new

        # Get the Class for the assocation name
        # i.e. :posts => Post
        def self.klass_for_association(association : String | Symbol)
          CRECTO_ASSOCIATIONS.select{|a| a[:key] == association.to_s && a[:this_klass] == self}.first[:klass]
        end

        # Get the foreign key for the association
        # i.e. :posts => :user_id
        def self.foreign_key_for_association(association : String | Symbol) : String?
          CRECTO_ASSOCIATIONS.select{|a| a[:key] == association.to_s && a[:this_klass] == self}.first[:foreign_key]
        end

        def self.foreign_key_for_association(klass : Crecto::Model.class)
          CRECTO_ASSOCIATIONS.select{|a| a[:klass] == klass && a[:this_klass] == self}.first[:foreign_key]
        end

        # Get the foreign key value from the relation object
        # i.e. :posts, post => post.user_id
        def self.foreign_key_value_for_association(association : String | Symbol, item)
          CRECTO_ASSOCIATIONS.select{|a| a[:key] == association.to_s && a[:this_klass] == self}.first[:foreign_key_value].call(item).as(PkeyValue)
        end

        # Set the value for the association
        # i.e. :posts, user, [posts] => user.posts = [posts]
        def self.set_value_for_association(association : String | Symbol, item, items)
          CRECTO_ASSOCIATIONS.select{|a| a[:key] == association.to_s && a[:this_klass] == self}.first[:set_association].call(item, items)
        end

        # Get the association type for the association
        # i.e. :posts => :has_many
        def self.association_type_for_association(association : String | Symbol)
          CRECTO_ASSOCIATIONS.select{|a| a[:key] == association.to_s && a[:this_klass] == self}.first[:association_type]
        end

        # Get the through association symbol
        # i.e. :posts => :user_posts (if has_many through)
        def self.through_key_for_association(association : String | Symbol) : String?
          CRECTO_ASSOCIATIONS.select{|a| a[:key] == association.to_s && a[:this_klass] == self}.first[:through]
        end
      end
    end
  end
end
