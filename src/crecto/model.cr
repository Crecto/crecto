module Crecto
  abstract class Model
    macro inherited
      include Crecto::Schema
      extend Crecto::Changeset({{@type}})
    end
  end
end
