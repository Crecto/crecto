module Crecto
  class EnumIntConverter(T)
    include Converter(T)

    def to_rs(item : T)
      item.to_i.as(DbValue)
    end

    def from_rs(rs : DB::ResultSet) : T
      T.from_value(rs.read(Int))
    end
  end
end
