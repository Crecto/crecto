module Crecto
  module Schema
    module Associations
      macro setup_associations
        # :nodoc:
        CRECTO_ASSOCIATIONS = Array(NamedTuple(association_type: Symbol,
          key: Symbol,
          this_klass: Crecto::Model.class,
          klass: Crecto::Model.class,
          foreign_key: Symbol,
          foreign_key_value: Proc(Crecto::Model, PkeyValue),
          set_association: Proc(Crecto::Model, (Array(Crecto::Model) | Crecto::Model), Nil),
          through: Symbol?)).new

        # Get the Class for the assocation name
        # i.e. :posts => Post
        def self.klass_for_association(association : Symbol)
          associations = CRECTO_ASSOCIATIONS.select { |a| a[:key] == association && a[:this_klass] == self }
          raise Crecto::AssociationError.new(association, self.name, :klass_for_association) if associations.empty?
          associations.first[:klass]
        end

        # Get the foreign key for the association
        # i.e. :posts => :user_id
        def self.foreign_key_for_association(association : Symbol) : Symbol?
          associations = CRECTO_ASSOCIATIONS.select { |a| a[:key] == association && a[:this_klass] == self }
          raise Crecto::AssociationError.new(association, self.name, :foreign_key_for_association) if associations.empty?
          associations.first[:foreign_key]
        end

        def self.foreign_key_for_association(klass : Crecto::Model.class)
          associations = CRECTO_ASSOCIATIONS.select { |a| a[:klass] == klass && a[:this_klass] == self }
          raise Crecto::AssociationError.new(:unknown, self.name, :foreign_key_for_association) if associations.empty?
          associations.first[:foreign_key]
        end

        # Get the foreign key value from the relation object
        # i.e. :posts, post => post.user_id
        def self.foreign_key_value_for_association(association : Symbol, item)
          associations = CRECTO_ASSOCIATIONS.select { |a| a[:key] == association && a[:this_klass] == self }
          raise Crecto::AssociationError.new(association, self.name, :foreign_key_value_for_association) if associations.empty?
          associations.first[:foreign_key_value].call(item).as(PkeyValue)
        end

        # Set the value for the association
        # i.e. :posts, user, [posts] => user.posts = [posts]
        def self.set_value_for_association(association : Symbol, item, items)
          associations = CRECTO_ASSOCIATIONS.select { |a| a[:key] == association && a[:this_klass] == self }
          raise Crecto::AssociationError.new(association, self.name, :set_value_for_association) if associations.empty?
          associations.first[:set_association].call(item, items)
        end

        # Get the association type for the association
        # i.e. :posts => :has_many
        def self.association_type_for_association(association : Symbol)
          associations = CRECTO_ASSOCIATIONS.select { |a| a[:key] == association && a[:this_klass] == self }
          raise Crecto::AssociationError.new(association, self.name, :association_type_for_association) if associations.empty?
          associations.first[:association_type]
        end

        # Get the through association symbol
        # i.e. :posts => :user_posts (if has_many through)
        def self.through_key_for_association(association : Symbol) : Symbol?
          associations = CRECTO_ASSOCIATIONS.select { |a| a[:key] == association && a[:this_klass] == self }
          return nil if associations.empty?
          associations.first[:through]
        end
      end
    end
  end
end
