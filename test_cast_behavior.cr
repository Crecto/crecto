require "spec"
require "./src/crecto"

class TestUser < Crecto::Model
  schema "users" do
    field :name, String
    field :company_id, Int32?
  end

  belongs_to :company, TestUser
end

puts "=== Testing cast behavior ==="

# Test what happens when we cast invalid values
puts "\n--- Testing string 'invalid' to Int32? ---"
begin
  user = TestUser.cast({company_id: "invalid"})
  puts "After cast - company_id: #{user.company_id.inspect} (type: #{user.company_id.class})"
rescue ex
  puts "Exception during cast: #{ex.message}"
end

puts "\n--- Testing string '0' to Int32? ---"
begin
  user = TestUser.cast({company_id: "0"})
  puts "After cast - company_id: #{user.company_id.inspect} (type: #{user.company_id.class})"
rescue ex
  puts "Exception during cast: #{ex.message}"
end

puts "\n--- Testing integer 0 to Int32? ---"
begin
  user = TestUser.cast({company_id: 0})
  puts "After cast - company_id: #{user.company_id.inspect} (type: #{user.company_id.class})"
rescue ex
  puts "Exception during cast: #{ex.message}"
end

puts "\n--- Testing string that can be converted to Int32 ---"
begin
  user = TestUser.cast({company_id: "123"})
  puts "After cast - company_id: #{user.company_id.inspect} (type: #{user.company_id.class})"
rescue ex
  puts "Exception during cast: #{ex.message}"
end

puts "\n--- Testing direct assignment (bypassing cast) ---"
user = TestUser.new
puts "Direct assignment - company_id: #{user.company_id.inspect}"

# Try to manually set an invalid value to see if it's possible
puts "\n--- Testing if we can set company_id to a string directly ---"
begin
  # This won't compile because company_id is typed as Int32?
  # user.company_id = "invalid"
  puts "Direct string assignment not possible due to type system"
rescue ex
  puts "Exception: #{ex.message}"
end

puts "\n--- Testing what to_query_hash shows ---"
user = TestUser.cast({company_id: 0})
puts "user.to_query_hash: #{user.to_query_hash}"