module Crecto
  module Schema
    module BelongsTo
      VALID_BELONGS_TO_OPTIONS = [:foreign_key]

      macro belongs_to(association_name, klass, **opts)
        # puts "belongs to " + {{association_name.id.stringify}}
      end
    end
  end
end