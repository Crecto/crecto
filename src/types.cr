require "json"

# :nodoc:
alias DbValue = Bool | Float32 | Float64 | Int64 | Int32 | Int16 | String | Time | JSON::Any | Nil
# :nodoc:
alias ArrayDbValue = Array(Bool) | Array(Float32) | Array(Float64) | Array(Int64) | Array(Int32) | Array(Int16) | Array(String) | Array(Time) | Array(JSON::Any) | Nil
# alias for String | Int32 | Int64 | Nil
alias PkeyValue = String | Int32 | Int64 | Nil
# :nodoc:
alias WhereType = Hash(Symbol, PkeyValue) | Hash(Symbol, DbValue) | Hash(Symbol, Array(DbValue)) | Hash(Symbol, Array(PkeyValue)) | Hash(Symbol, Array(Int32)) | Hash(Symbol, Array(Int64)) | Hash(Symbol, Array(String)) | Hash(Symbol, Int32 | String) | Hash(Symbol, Int64 | String) | Hash(Symbol, Int32) | Hash(Symbol, Int64) | Hash(Symbol, Nil) | Hash(Symbol, String) | Hash(Symbol, Int32 | Int64 | String) | Hash(Symbol, Int32 | Int64 | String | Nil) | NamedTuple(clause: String, params: Array(DbValue | PkeyValue))
# :nodoc:
alias Json = JSON::Any
