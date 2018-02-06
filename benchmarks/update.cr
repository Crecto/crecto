#
# 10,000 updates
#

require "benchmark"
require "../src/crecto"
require "./benchmark_helper"

users = make_users(true)

def change_users_attributes(users)
  users.each do |user|
    user.name = Random::Secure.hex(8).to_s
    user.things = Random.rand(100)
    user.smallnum = Random.rand(9).to_i16
    user.nope = Random.rand(100.0)
    user.yep = [true, false].sample
    user.some_date = random_time
  end
end

Benchmark.bm do |x|
  x.report("update crecto : ") do
    change_users_attributes(users)
    users.each do |user|
      Repo.update(user)
    end
  end

  DB.open "postgresql://localhost:5432/crecto_test" do |db|
    x.report("update crystal-pg : ") do
      change_users_attributes(users)
      users.each do |user|
        db.exec "UPDATE users SET (name, things, smallnum, nope, yep, some_date) = ($1, $2, $3, $4, $5, $6) WHERE id=$7 RETURNING *", user.name, user.things, user.smallnum, user.nope, user.yep, user.some_date, user.id
      end
    end
  end
end
