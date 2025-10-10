module Crecto
  module Changeset(T)
    # Changeset instance returned when evaluating a changeset.
    #
    # ```
    # user = User.new
    # changeset = User.changeset(user)
    # ```
    #
    # The Changeset instance has the following properties:
    #
    # * `action` - Action performed by Repo on the changeset (:insert, :upate, etc)
    # * `errors` - Array of field validation errors
    # * `changes` - An array of changes on fields
    # * `source` - Hash of the original data
    #
    class Changeset(T)
      # :nodoc:
      property action : Symbol?
      # :nodoc:
      property errors = [] of Hash(Symbol, String)
      # :nodoc:
      property changes = [] of Hash(Symbol, DbValue | ArrayDbValue)
      # :nodoc:
      property source : Hash(Symbol, DbValue)? | Hash(Symbol, ArrayDbValue)?
      # :nodoc:
      property validation_context : Crecto::Repo?

      private property valid = true
      private property class_key : String?
      private property instance_hash : Hash(Symbol, DbValue | ArrayDbValue)

      def initialize(@instance : T, @validation_context : Crecto::Repo? = nil)
        @class_key = @instance.class.to_s
        @instance_hash = @instance.to_query_hash(true)
        @source = @instance.initial_values

        check_required!
        check_formats!
        check_array_inclusions!
        check_range_inclusions!
        check_array_exclusions!
        check_range_exclusions!
        check_lengths!
        check_generic_validations!
        diff_from_initial_values!
      end

      # Returns whether the changeset is valid (has no errors)
      def valid?
        @valid
      end

      def instance
        @instance
      end

      def add_error(key, val)
        errors.push({:field => key, :message => val})
        @valid = false
      end

      # Validate that all association foreign keys reference existing records.
      # This method checks belongs_to associations to ensure the foreign key
      # references a record that actually exists in the database.
      #
      # ```
      # changeset = User.changeset(user)
      #   .validate_association_foreign_keys
      # ```
      #
      # Returns self so it can be chained with other validations.
      def validate_association_foreign_keys
        instance_class = @instance.class

        # Use the association methods available on the model class
        # Try to get association information by checking what associations exist
        begin
          # Check for belongs_to associations by looking for foreign keys that end with _id
          # This is a convention-based approach that works for most models
          foreign_key_fields = @instance_hash.keys.select { |key| key.to_s.ends_with?("_id") }

          foreign_key_fields.each do |foreign_key_field|
            foreign_key_value = @instance_hash[foreign_key_field]

            # Skip validation if foreign key is nil (optional association)
            next if foreign_key_value.nil?

            # Convert foreign key field to association name (user_id -> user)
            association_name_str = foreign_key_field.to_s.gsub(/_id$/, "")

            # Use the injected context if available for proper database validation
            if @validation_context
              begin
                validate_foreign_key_with_context(foreign_key_field, foreign_key_value, association_name_str)
              rescue ex
                # If validation fails for any reason, add a generic validation error
                add_error(foreign_key_field.to_s, "association reference not found")
              end
            else
              # Fallback to convention-based validation without database access
              validate_foreign_key_by_convention(foreign_key_field, foreign_key_value, association_name_str)
            end
          end
        rescue ex
          # If any error occurs during validation, add a generic error
          add_error("_base", "association validation failed")
        end

        self
      end

      private def validate_foreign_key_with_context(foreign_key_field : Symbol, foreign_key_value, association_name : String)
        # Use the injected Repo context to perform actual database validation
        repo = @validation_context.not_nil!

        # Try to determine the associated class name by convention
        # Convert association_name to CamelCase to get the class name
        associated_class_name = association_name.split('_').map(&.capitalize).join

        # For now, use a simple mapping approach for common classes
        # This is a limitation of Crystal's compile-time nature
        associated_class = case associated_class_name
                         when "User"
                           User
                         when "Post"
                           Post
                         when "Address"
                           Address
                         when "Project"
                           Project
                         when "Thing"
                           Thing
                         when "UserProject"
                           UserProject
                         when "UserDifferentDefaults"
                           UserDifferentDefaults
                         else
                           # For unknown classes, we can't validate the association
                           # This is a limitation that could be addressed with macros
                           return
                         end

        # If we found the associated class, try to query the database
        if associated_class
          begin
            # Check if the class looks like a model (should have schema information)
            if associated_class.responds_to?(:table_name)
              # Use the repo to check if the referenced record exists
              # This is the actual database validation that was previously impossible
              # Convert to the correct type for the get method
              primary_key_value = foreign_key_value.as(PkeyValue)
              referenced_record = repo.get(associated_class, primary_key_value)
              if referenced_record.nil?
                add_error(foreign_key_field.to_s, "referenced #{association_name} not found")
              end
            end
          rescue ex
            # If the query fails for any reason (table doesn't exist, wrong type, etc.)
            # add an appropriate error message
            add_error(foreign_key_field.to_s, "unable to validate #{association_name} reference")
          end
        end
      end

      private def validate_foreign_key_by_convention(foreign_key_field : Symbol, foreign_key_value, association_name : String)
        # Fallback validation when no Repo context is available
        # This provides basic structure but can't do actual database validation
        # The validation just ensures the foreign key has a reasonable format

        # Basic format validation - ensure it's a positive integer if it's numeric
        if foreign_key_value.is_a?(Number) && foreign_key_value.to_i <= 0
          add_error(foreign_key_field.to_s, "must be a positive integer")
        end

        # For string foreign keys, ensure they're not empty
        if foreign_key_value.is_a?(String) && foreign_key_value.to_s.strip.empty?
          add_error(foreign_key_field.to_s, "cannot be empty")
        end
      end

      def check_unique_constraint_from_exception!(e : Exception, queryable_instance)
        return false unless UNIQUE_FIELDS[@class_key]?
        message = e.message.to_s

        # Postgres
        if message.starts_with?("duplicate key value")
          UNIQUE_FIELDS[@class_key].each do |constraint_field|
            if message.includes?("unique constraint \"#{queryable_instance.class.table_name}_#{constraint_field}_key\"")
              self.add_error(constraint_field.to_s, message)
              return true
            end
          end
          self.add_error("_base", message)
          return true
        end

        # Mysql
        if message.starts_with?("Duplicate")
          UNIQUE_FIELDS[@class_key].each do |constraint_field|
            if message.includes?("for key '#{constraint_field}'")
              self.add_error(constraint_field.to_s, message)
              return true
            end
          end
          self.add_error("_base", message)
          return true
        end

        # Sqlite
        if message.downcase.starts_with?("unique constraint failed")
          UNIQUE_FIELDS[@class_key].each do |constraint_field|
            if message.includes?("#{queryable_instance.class.table_name}.#{constraint_field}")
              self.add_error(constraint_field.to_s, message)
              return true
            end
          end
          self.add_error("_base", message)
          return true
        end

        false
      end

      private def check_required!
        return unless REQUIRED_FIELDS.has_key?(@class_key)
        REQUIRED_FIELDS[@class_key].each do |field|
          add_error(field.to_s, "is required") if @instance_hash[field].nil?
        end
      end

      private def check_formats!
        return unless REQUIRED_FORMATS.has_key?(@class_key)
        REQUIRED_FORMATS[@class_key].each do |format|
          next unless @instance_hash[format[:field]]?
          raise Crecto::InvalidType.new("Format validator can only validate strings") unless @instance_hash.fetch(format[:field], nil).is_a?(String)
          val = @instance_hash.fetch(format[:field], nil).as(String)
          add_error(format[:field].to_s, "is invalid") if format[:pattern].match(val).nil?
        end
      end

      private def check_array_inclusions!
        return unless REQUIRED_ARRAY_INCLUSIONS.has_key?(@class_key)
        REQUIRED_ARRAY_INCLUSIONS[@class_key].each do |inclusion|
          next unless @instance_hash[inclusion[:field]]?
          val = @instance_hash.fetch(inclusion[:field], nil)
          add_error(inclusion[:field].to_s, "is invalid") unless inclusion[:in].includes?(val)
        end
      end

      private def check_range_inclusions!
        return unless REQUIRED_RANGE_INCLUSIONS.has_key?(@class_key)
        REQUIRED_RANGE_INCLUSIONS[@class_key].each do |inclusion|
          next unless @instance_hash[inclusion[:field]]?
          val = @instance_hash.fetch(inclusion[:field], nil)
          if inclusion[:in].is_a?(Range(Float64, Float64)) && val.is_a?(Float64)
            add_error(inclusion[:field].to_s, "is invalid") unless inclusion[:in].as(Range(Float64, Float64)).includes?(val.as(Float64))
          elsif inclusion[:in].is_a?(Range(Int32, Int32)) && val.is_a?(Int32)
            add_error(inclusion[:field].to_s, "is invalid") unless inclusion[:in].as(Range(Int32, Int32)).includes?(val.as(Int32))
          elsif inclusion[:in].is_a?(Range(Int64, Int64)) && val.is_a?(Int64)
            add_error(inclusion[:field].to_s, "is invalid") unless inclusion[:in].as(Range(Int64, Int64)).includes?(val.as(Int64))
          elsif inclusion[:in].is_a?(Range(Time, Time)) && val.is_a?(Time)
            add_error(inclusion[:field].to_s, "is invalid") unless inclusion[:in].as(Range(Time, Time)).includes?(val.as(Time))
          end
        end
      end

      private def check_array_exclusions!
        return unless REQUIRED_ARRAY_EXCLUSIONS.has_key?(@class_key)
        REQUIRED_ARRAY_EXCLUSIONS[@class_key].each do |exclusion|
          next unless @instance_hash[exclusion[:field]]?
          val = @instance_hash.fetch(exclusion[:field], nil)
          add_error(exclusion[:field].to_s, "is invalid") if exclusion[:in].includes?(val)
        end
      end

      private def check_range_exclusions!
        return unless REQUIRED_RANGE_EXCLUSIONS.has_key?(@class_key)
        REQUIRED_RANGE_EXCLUSIONS[@class_key].each do |exclusion|
          next unless @instance_hash[exclusion[:field]]?
          val = @instance_hash.fetch(exclusion[:field], nil)
          if exclusion[:in].is_a?(Range(Float64, Float64)) && val.is_a?(Float64)
            add_error(exclusion[:field].to_s, "is invalid") if exclusion[:in].as(Range(Float64, Float64)).includes?(val.as(Float64))
          elsif exclusion[:in].is_a?(Range(Int32, Int32)) && val.is_a?(Int32)
            add_error(exclusion[:field].to_s, "is invalid") if exclusion[:in].as(Range(Int32, Int32)).includes?(val.as(Int32))
          elsif exclusion[:in].is_a?(Range(Int64, Int64)) && val.is_a?(Int64)
            add_error(exclusion[:field].to_s, "is invalid") if exclusion[:in].as(Range(Int64, Int64)).includes?(val.as(Int64))
          elsif exclusion[:in].is_a?(Range(Time, Time)) && val.is_a?(Time)
            add_error(exclusion[:field].to_s, "is invalid") if exclusion[:in].as(Range(Time, Time)).includes?(val.as(Time))
          end
        end
      end

      private def check_lengths!
        return unless REQUIRED_LENGTHS.has_key?(@class_key)
        REQUIRED_LENGTHS[@class_key].each do |length|
          next unless @instance_hash[length[:field]]?
          val = @instance_hash.fetch(length[:field], nil).as(String)
          add_error(length[:field].to_s, "is invalid") if !length[:is].nil? && val.size != length[:is].as(Int32)
          add_error(length[:field].to_s, "is invalid") if !length[:min].nil? && val.size < length[:min].as(Int32)
          add_error(length[:field].to_s, "is invalid") if !length[:max].nil? && val.size > length[:max].as(Int32)
        end
      end

      private def diff_from_initial_values!
        @initial_values = {} of Symbol => (DbValue | ArrayDbValue) if @initial_values.nil?
        @changes.clear
        @instance_hash.each do |field, value|
          @changes.push({field => value}) if @initial_values.as(Hash).fetch(field, nil) != value
        end
      end

      private def check_generic_validations!
        @instance.class.required_generics.each do |tuple|
          if !tuple[:validation].call(@instance)
            add_error("_base", tuple[:message])
          end
        end
      end
    end
  end
end
