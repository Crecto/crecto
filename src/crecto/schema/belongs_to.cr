module Crecto
  module Schema
    module BelongsTo
      macro belongs_to(association)
        puts "belongs to " + {{association.id.stringify}}
      end
    end
  end
end