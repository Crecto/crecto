module Crecto
  module Schema
    module HasMany
      macro has_many(association)
        puts "has many " + {{association.id.stringify}}
      end
    end
  end
end