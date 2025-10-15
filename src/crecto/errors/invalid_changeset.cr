require "./crecto_error"

module Crecto
  # :nodoc:
  class InvalidChangeset(T) < CrectoError
    getter changeset

    def initialize(@changeset : Changeset::Changeset(T))
    end

    def message
      error_list = [] of String
      changeset.errors.each do |error|
        error_list << "#{error[0]}: #{error[1]}"
      end

      "Failed to #{changeset.action} #{changeset.instance.class}: #{error_list.join(", ")}"
    end
  end
end
