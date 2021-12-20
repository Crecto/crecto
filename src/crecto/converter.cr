module Crecto
  module Converter(T)
    abstract def to_rs(item : T)
    abstract def from_rs(rs : DB::ResultSet) : T
  end
end
