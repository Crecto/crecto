#
# 10,000 deletes
#

require "benchmark"
require "../src/crecto"
require "./benchmark_helper"

users = make_users(true)
pg_users = make_users(true)

Benchmark.bm do |x|
  x.report("delete crecto : ") do
    users.each do |user|
      Repo.delete(user)
    end
  end

  DB.open "postgresql://localhost:5432/crecto_test" do |db|
    x.report("delete crystal-pg : ") do
      pg_users.each do |user|
        db.exec "DELETE FROM users WHERE id=$1 RETURNING *", user.id
      end
    end
  end
end
