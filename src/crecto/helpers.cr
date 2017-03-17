module Crecto
  module Helpers
    def self.jsonize(obj)
        case obj
        when NamedTuple
          jsonize(obj.to_h)
        when Array
          obj.map { |o| jsonize(o) }.as(JSON::Type)
        when Hash
          h = {} of String => JSON::Type
          obj.each { |k, v| h[k.to_s] = jsonize(v) }
          h.as(JSON::Type)
        when Int32
          obj.to_i64.as(JSON::Type)
        when Time
          obj.to_json.as(JSON::Type)
        else obj.as(JSON::Type)
        end
      end
  end
end