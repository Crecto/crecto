require "./crecto/errors/*"
require "./crecto/schema/*"
require "./crecto/adapters/*"
require "./crecto/changeset/*"
require "./crecto/*"

alias DbBigInt = Int32 | Int64
alias DbValue = Bool | Float32 | Float64 | Int64 | Int32 | String | Time | Nil
alias PkeyValue = Int32 | Int64 | Nil

module Crecto
end
