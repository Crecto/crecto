#
# 10,000 inserts
#

require "benchmark"
require "../src/crecto"
require "./benchmark_helper"

users = make_users

Benchmark.bm do |x|
  x.report("insert crecto : ") do
    users.each do |user|
      Repo.insert(user)
    end
  end

  DB.open "postgresql://localhost:5432/crecto_test" do |db|
    x.report("insert crystal-pg : ") do
      users.each do |user|
        db.exec "INSERT INTO users (name, things, smallnum, nope, yep, some_date) VAlUES ($1, $2, $3, $4, $5, $6) RETURNING *", user.name, user.things, user.smallnum, user.nope, user.yep, user.some_date
      end
    end
  end
end
