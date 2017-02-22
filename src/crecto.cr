require "json"
require "./crecto/errors/*"
require "./crecto/schema/*"
require "./crecto/adapters/*"
require "./crecto/changeset/*"
require "./crecto/*"

# :nodoc:
alias DbBigInt = Int32 | Int64
# :nodoc:
alias DbValue = Bool | Float32 | Float64 | Int64 | Int32 | String | Time | Nil
# :nodoc:
alias PkeyValue = Int32 | Int64 | Nil
# :nodoc:
alias WhereType = Hash(Symbol, PkeyValue) | Hash(Symbol, DbValue) | Hash(Symbol, Array(DbValue)) | Hash(Symbol, Array(PkeyValue)) | Hash(Symbol, Array(Int32)) | Hash(Symbol, Array(Int64)) | Hash(Symbol, Array(String)) | Hash(Symbol, Int32 | String) | Hash(Symbol, Int32) | Hash(Symbol, Int64) | Hash(Symbol, String) | Hash(Symbol, Int32 | Int64 | String | Nil) | NamedTuple(clause: String, params: Array(DbValue | PkeyValue))

module Crecto
end
