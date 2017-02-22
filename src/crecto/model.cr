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
      extend Crecto::Changeset({{@type}})
    end
  end
end
