module Crecto
  module Schema
    module HasMany
      VALID_HAS_MANY_OPTIONS = [:foreign_key]

      macro has_many(association_name, klass, **opts)
        # puts "has many " + {{association_name.id.stringify}}
      end
    end
  end
end