require "json"
require "./crecto/errors/*"
require "./crecto/schema/*"
require "./crecto/adapters/*"
require "./crecto/changeset/*"
require "./crecto/repo/*"
require "./crecto/*"

# :nodoc:
alias DbValue = Bool | Float32 | Float64 | Int64 | Int32 | String | Time | JSON::Any | Nil
# alias for Int32 | Int64 | Nil
alias PkeyValue = Int32 | Int64 | Nil
# :nodoc:
alias WhereType = Hash(Symbol, PkeyValue) | Hash(Symbol, DbValue) | Hash(Symbol, Array(DbValue)) | Hash(Symbol, Array(PkeyValue)) | Hash(Symbol, Array(Int32)) | Hash(Symbol, Array(Int64)) | Hash(Symbol, Array(String)) | Hash(Symbol, Int32 | String) | Hash(Symbol, Int64 | String) | Hash(Symbol, Int32) | Hash(Symbol, Int64) | Hash(Symbol, Nil) | Hash(Symbol, String) | Hash(Symbol, Int32 | Int64 | String) | Hash(Symbol, Int32 | Int64 | String | Nil) | NamedTuple(clause: String, params: Array(DbValue | PkeyValue))
# :nodoc:
alias Json = JSON::Any

module Crecto
end
