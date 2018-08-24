#
# 10000 select where queries
#

require "benchmark"
require "../src/crecto"
require "./benchmark_helper"

users = make_users(true, 10000)
ids = users.map(&.id)
queries = ids.map { |id| Query.where(id: id.to_s) }

Benchmark.bm do |x|
  x.report("select where crecto:") do
    queries.each do |query|
      Repo.all(User, query)
    end
  end

  DB.open "postgresql://localhost:5432/crecto_test" do |db|
    x.report("select where crystal-pg:") do
      ids.each do |id|
        db.query "SELECT * FROM users WHERE users.id = $1", id do |rs|
        end
      end
    end
  end
end
