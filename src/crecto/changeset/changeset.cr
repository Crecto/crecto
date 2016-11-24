module Crecto
  module Changeset
    class Changeset
      property action : Symbol?
      property errors = [] of Hash(Symbol, String)
      property changes = [] of Hash(Symbol, String)
      property valid = true

      def initialize(instance)
        instance_hash = instance.to_query_hash
        check_required!(instance_hash)
        check_formats!(instance_hash)
        check_inclusions!(instance_hash)
      end

      def valid?
        @valid
      end

      private def check_required!(instance_hash)
        REQUIRED_FIELDS.each do |field|
          add_error(field.to_s, "is required") unless instance_hash.has_key?(field)
        end
      end

      private def check_formats!(instance_hash)
        REQUIRED_FORMATS.each do |format|
          next unless instance_hash.has_key?(format[:field])
          raise Crecto::InvalidType.new("Format validator can only validate strings") unless instance_hash.fetch(format[:field]).is_a?(String)
          val = instance_hash.fetch(format[:field]).as(String)
          add_error(format[:field].to_s, "is invalid") if format[:pattern].match(val).nil?
        end
      end

      private def check_inclusions!(instance_hash)
        REQUIRED_INCLUSIONS.each do |inclusion|
          next unless instance_hash.has_key?(inclusion[:field])
          val = instance_hash.fetch(inclusion[:field])
          add_error(inclusion[:field].to_s, "is invalid") unless inclusion[:in].includes?(val)
        end
      end

      private def add_error(key, val)
        errors.push({field: key, message: val}.to_h)
        @valid = false
      end

    end
  end
end