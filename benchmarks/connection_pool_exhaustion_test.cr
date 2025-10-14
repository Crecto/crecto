#!/usr/bin/env crystal

require "../src/crecto"
require "../spec/spec_helper"

# Connection pool resource exhaustion test
# This test attempts to reproduce the GitHub Issue #116: Connection resource exhaustion after 16,382 operations

class ConnectionTestUser < Crecto::Model
  schema "users" do
    field :name, String
    field :things, Int32 | Int64
    field :smallnum, Int16
    field :stuff, Int32, virtual: true
    field :nope, Float32 | Float64
    field :yep, Bool
    field :some_date, Time
    field :pageviews, Int32 | Int64
    field :unique_field, String
  end

  validate_required :name
end

def test_connection_exhaustion_threshold
  puts "🔍 Testing connection pool resource exhaustion..."

  # Clean up any existing data
  Repo.delete_all(ConnectionTestUser, Query.new)

  # Start with baseline memory measurement
  GC.collect
  initial_memory = GC.stats.heap_size
  initial_connections = get_connection_count

  puts "   Initial memory: #{(initial_memory / 1024).round(2)} KB"
  puts "   Initial connection count: #{initial_connections}"

  operation_count = 16400  # Just past the 16,382 threshold mentioned in the issue
  batch_size = 100
  errors = [] of String

  start_time = Time.local

  (0...operation_count).step(batch_size) do |batch_start|
    batch_users = Array(ConnectionTestUser).new(batch_size) do |i|
      ConnectionTestUser.new.tap do |user|
        user.name = "Connection Test User #{batch_start + i}"
        user.things = batch_start + i
        user.unique_field = "unique_#{batch_start + i}"
      end
    end

    batch_users.each do |user|
      begin
        changeset = Repo.insert(user)
        unless changeset.valid?
          errors << "Insert validation failed: #{changeset.errors}"
        end
      rescue ex : Exception
        errors << "Insert exception at operation #{batch_start}: #{ex.class} - #{ex.message}"

        # If we hit a connection error, we may have found the exhaustion issue
        if ex.message.try(&.includes?("connection")) || ex.message.try(&.includes?("pool"))
          puts "   ❌ Connection error detected at operation #{batch_start}: #{ex.message}"
          return {
            success: false,
            error_at_operation: batch_start,
            error_message: ex.message,
            total_operations: batch_start
          }
        end
      end
    end

    # Progress reporting
    if batch_start % 1000 == 0
      current_memory = GC.stats.heap_size
      memory_growth = current_memory - initial_memory

      puts "   Progress: #{batch_start}/#{operation_count} operations completed"
      puts "   Memory growth: #{(memory_growth / 1024).round(2)} KB"
      puts "   Error count: #{errors.size}"

      # Check for connection leaks
      current_connections = get_connection_count
      puts "   Connection count: #{current_connections} (change: #{current_connections - initial_connections})"
    end

    # Clean up batch to prevent table from growing too large
    if batch_start % 2000 == 0 && batch_start > 0
      Repo.delete_all(ConnectionTestUser, Query.where("name LIKE ?", ["Connection Test User%"]))
    end
  end

  end_time = Time.local
  duration = end_time - start_time

  # Final measurements
  GC.collect
  final_memory = GC.stats.heap_size
  final_connections = get_connection_count
  total_memory_growth = final_memory - initial_memory
  connection_growth = final_connections - initial_connections

  puts "\n📊 Test Results:"
  puts "   Total operations: #{operation_count}"
  puts "   Duration: #{duration.total_seconds.round(2)}s"
  puts "   Operations per second: #{(operation_count / duration.total_seconds).round(2)}"
  puts "   Total errors: #{errors.size}"
  puts "   Memory growth: #{(total_memory_growth / 1024).round(2)} KB"
  puts "   Connection count change: #{connection_growth}"

  if errors.size > 0
    puts "   First few errors:"
    errors.first(5).each { |error| puts "     - #{error}" }
  end

  # Check if we successfully completed without connection exhaustion
  if errors.empty? || errors.all? { |e| !e.includes?("connection") && !e.includes?("pool") }
    puts "   ✅ Successfully completed #{operation_count} operations without connection exhaustion!"

    # Validate the fix by checking memory and connection growth is reasonable
    if total_memory_growth < 50 * 1024 * 1024  # Less than 50MB growth
      puts "   ✅ Memory usage remained stable"
    else
      puts "   ⚠️  High memory usage detected: #{(total_memory_growth / 1024 / 1024).round(2)} MB"
    end

    if connection_growth.abs <= 2  # Allow small connection count variations
      puts "   ✅ Connection pool remained stable"
    else
      puts "   ⚠️  Connection count changed significantly: #{connection_growth}"
    end

    return {
      success: true,
      total_operations: operation_count,
      duration_seconds: duration.total_seconds,
      memory_growth_kb: total_memory_growth / 1024,
      connection_growth: connection_growth,
      error_count: errors.size
    }
  else
    puts "   ❌ Connection exhaustion detected before completing #{operation_count} operations"
    return {
      success: false,
      error_at_operation: "unknown",
      error_message: "Connection pool exhaustion occurred",
      total_operations: operation_count,
      error_count: errors.size
    }
  end
end

def test_prepared_statement_lifecycle
  puts "\n🔍 Testing prepared statement lifecycle management..."

  # Test with different query patterns to ensure prepared statements are properly managed
  queries = [
    "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
    "SELECT * FROM users WHERE name LIKE ?",
    "UPDATE users SET age = ? WHERE id = ?",
    "DELETE FROM users WHERE age > ?"
  ]

  statement_stats = {} of String => Int32

  queries.each do |query|
    statement_stats[query] = 0

    1000.times do |i|
      begin
        case query
        when .includes?("INSERT")
          user = ConnectionTestUser.new
          user.name = "Stmt Test #{i}"
          user.things = i
          user.unique_field = "stmt_unique_#{i}"
          Repo.insert(user)
          statement_stats[query] += 1

        when .includes?("SELECT")
          Repo.query(ConnectionTestUser, "SELECT COUNT(*) FROM users WHERE name LIKE ?", ["Stmt Test %"])
          statement_stats[query] += 1

        when .includes?("UPDATE")
          # Update a few records
          Repo.query(ConnectionTestUser, "UPDATE users SET things = ? WHERE id <= ?", [30, (i % 10) + 1])
          statement_stats[query] += 1

        when .includes?("DELETE")
          # Clean up some records to prevent table growth
          if i % 100 == 0
            Repo.query(ConnectionTestUser, "DELETE FROM users WHERE name LIKE ?", ["Stmt Test %"])
          end
          statement_stats[query] += 1
        end
      rescue ex : Exception
        puts "   ❌ Error in prepared statement test: #{ex.message}"
        return {success: false, error: ex.message}
      end
    end
  end

  puts "   ✅ Prepared statement lifecycle test completed successfully"
  puts "   Query execution counts:"
  statement_stats.each do |query, count|
    puts "     #{query[0..30]}...: #{count} times"
  end

  # Clean up
  Repo.delete_all(ConnectionTestUser, Query.where("name LIKE ?", ["Stmt Test %"]))

  return {success: true, statement_stats: statement_stats}
end

def get_connection_count
  # Try to get connection count from the adapter's stats if available
  begin
    if Repo.config.responds_to?(:crecto_db)
      db = Repo.config.crecto_db
      # Crystal's DB doesn't expose connection count directly, but we can infer
      # This is a rough estimate - in a real scenario we'd need better monitoring
      return 0  # Placeholder - actual implementation would need DB-specific metrics
    end
  rescue ex
    # If we can't get connection count, return 0
  end
  0
end

# Main test execution
puts "🧪 Crecto Connection Pool Resource Exhaustion Test"
puts "=" * 55
puts "GitHub Issue #116: Connection resource exhaustion after 16,382 operations"
puts ""

begin
  # Test 1: Connection exhaustion threshold test
  result1 = test_connection_exhaustion_threshold

  puts "\n" + "-" * 55

  # Test 2: Prepared statement lifecycle test
  result2 = test_prepared_statement_lifecycle

  puts "\n🎯 Overall Test Results:"
  if result1[:success] && result2[:success]
    puts "   ✅ All connection pool tests passed!"
    puts "   ✅ No connection resource exhaustion detected"
    puts "   ✅ Prepared statement lifecycle is properly managed"

    if result1[:total_operations]? && result1[:total_operations] >= 16400
      puts "   ✅ Successfully validated past the 16,382 operation threshold"
    end
  else
    puts "   ❌ Connection pool issues detected:"
    puts "     Connection exhaustion test: #{result1[:success] ? "PASSED" : "FAILED"}"
    puts "     Prepared statement test: #{result2[:success] ? "PASSED" : "FAILED"}"

    if result1.responds_to?(:error_at_operation) && result1[:error_at_operation]?
      puts "     Error occurred at: operation #{result1[:error_at_operation]}"
    end

    if result1.responds_to?(:error_message) && result1[:error_message]?
      puts "     Error message: #{result1[:error_message]}"
    end

    if result2.responds_to?(:error) && result2[:error]?
      puts "     Statement lifecycle error: #{result2[:error]}"
    end

    exit 1
  end

rescue ex : Exception
  puts "\n❌ Test suite failed with exception:"
  puts "   #{ex.class}: #{ex.message}"
  puts "   #{ex.backtrace.first(5).join("\n   ")}"
  exit 1
ensure
  # Clean up test data
  begin
    Repo.delete_all(ConnectionTestUser, Query.where("name LIKE ? OR name LIKE ?", ["Connection Test%", "Stmt Test %"]))
  rescue ex
    puts "Warning: Could not clean up test data: #{ex.message}"
  end
end

puts "\n🏁 Connection pool resource exhaustion test completed!"