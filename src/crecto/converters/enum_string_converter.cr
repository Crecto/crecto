module Crecto
  class EnumStringConverter(T)
    include Converter(T)

    def to_rs(item : T)
      item.to_s.as(DbValue)
    end

    def from_rs(rs : DB::ResultSet) : T
      T.parse(rs.read(String))
    end
  end
end
