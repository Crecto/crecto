require "json"

# :nodoc:
alias DbValue = Bool | Float32 | Float64 | Int64 | Int32 | Int16 | Int8 | String | Time | JSON::Any | Nil
# :nodoc:
alias ArrayDbValue = Array(Bool) | Array(Float32) | Array(Float64) | Array(Int64) | Array(Int32) | Array(Int16) | Array(Int8) | Array(String) | Array(Time) | Array(JSON::Any) | Nil
# alias for String | Int32 | Int64 | Nil
alias PkeyValue = String | Int8 | Int16 | Int32 | Int64 | Nil
# :nodoc:
alias WhereType = Hash(String, PkeyValue) | Hash(String, DbValue) | Hash(String, Array(DbValue)) | Hash(String, Array(PkeyValue)) | Hash(String, Array(Int32)) | Hash(String, Array(Int64)) | Hash(String, Array(String)) | Hash(String, Int32 | String) | Hash(String, Int64 | String) | Hash(String, Int32) | Hash(String, Int64) | Hash(String, Nil) | Hash(String, String) | Hash(String, Int32 | Int64 | String) | Hash(String, Int32 | Int64 | String | Nil) | NamedTuple(clause: String, params: Array(DbValue | PkeyValue))
# :nodoc:
alias Json = JSON::Any
