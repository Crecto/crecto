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

      private property valid = true
      private property class_key : String?
      private property instance_hash : Hash(Symbol, DbValue | ArrayDbValue)

      def initialize(@instance : T)
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
          raise Crecto::InvalidType.new("Format validator can only validate strings") unless @instance_hash.fetch(format[:field]).is_a?(String)
          val = @instance_hash.fetch(format[:field]).as(String)
          add_error(format[:field].to_s, "is invalid") if format[:pattern].match(val).nil?
        end
      end

      private def check_array_inclusions!
        return unless REQUIRED_ARRAY_INCLUSIONS.has_key?(@class_key)
        REQUIRED_ARRAY_INCLUSIONS[@class_key].each do |inclusion|
          next unless @instance_hash[inclusion[:field]]?
          val = @instance_hash.fetch(inclusion[:field])
          add_error(inclusion[:field].to_s, "is invalid") unless inclusion[:in].includes?(val)
        end
      end

      private def check_range_inclusions!
        return unless REQUIRED_RANGE_INCLUSIONS.has_key?(@class_key)
        REQUIRED_RANGE_INCLUSIONS[@class_key].each do |inclusion|
          next unless @instance_hash[inclusion[:field]]?
          val = @instance_hash.fetch(inclusion[:field])
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
          val = @instance_hash.fetch(exclusion[:field])
          add_error(exclusion[:field].to_s, "is invalid") if exclusion[:in].includes?(val)
        end
      end

      private def check_range_exclusions!
        return unless REQUIRED_RANGE_EXCLUSIONS.has_key?(@class_key)
        REQUIRED_RANGE_EXCLUSIONS[@class_key].each do |exclusion|
          next unless @instance_hash[exclusion[:field]]?
          val = @instance_hash.fetch(exclusion[:field])
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
          val = @instance_hash.fetch(length[:field]).as(String)
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
