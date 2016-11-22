module Crecto
  module Schema
    module HasOne
      macro has_one(association)
        puts "has one " + {{association.id.stringify}}
      end
    end
  end
end