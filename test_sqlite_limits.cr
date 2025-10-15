#!/usr/bin/env crystal
require "./spec/load/load_test_helper"

# Test SQLite-specific limitations under load

puts "SQLite Limitations Test"
puts "=" * 50

setup_test_database

# Test 1: Database locking issues
puts "\n1. Testing concurrent writes (potential lock contention)"
channel = Channel(Nil).new
results = [] of {Int32, Bool, String?}
results_lock = Mutex.new

# Spawn multiple writers trying to insert simultaneously
20.times do |thread_id|
  spawn do
    begin
      50.times do |i|
        model = Crecto::LoadTesting::LoadTestModel.new
        model.name = "Concurrent Write #{thread_id}-#{i}"
        model.value = thread_id * 100 + i
        model.created_at = Time.local

        result = Crecto::LoadTesting::TestRepo.insert(model)

        if result.is_a?(Crecto::Changeset::Changeset) && !result.valid?
          results_lock.synchronize do
            results << {thread_id, false, "Validation: #{result.errors}"}
          end
          break
        end
      end

      results_lock.synchronize do
        results << {thread_id, true, nil}
      end
    rescue ex
      results_lock.synchronize do
        results << {thread_id, false, ex.message}
      end
    end
    channel.send(nil)
  end
end

20.times { channel.receive }

success_count = results.count { |_, success, _| success }
failure_count = results.count { |_, success, _| !success }

puts "Successful threads: #{success_count}/20"
puts "Failed threads: #{failure_count}/20"

if failure_count > 0
  puts "\nFailure details:"
  results.select { |_, success, _| !success }.first(5).each do |thread_id, _, error|
    puts "  Thread #{thread_id}: #{error}"
  end
end

# Test 2: High volume insert with small batches
puts "\n2. Testing high volume inserts in batches"
channel = Channel(Nil).new
batch_results = [] of {Int32, Int32, String?}
batch_lock = Mutex.new

10.times do |batch_id|
  spawn do
    begin
      successful = 0
      errors = [] of String

      # Try to insert 200 records
      Crecto::LoadTesting::TestRepo.transaction! do |tx|
        200.times do |i|
          model = Crecto::LoadTesting::LoadTestModel.new
          model.name = "Batch #{batch_id}-Item #{i}"
          model.value = batch_id * 1000 + i
          model.created_at = Time.local

          begin
            tx.insert!(model)
            successful += 1
          rescue ex
            errors << (ex.message || "Unknown error")
          end
        end
      end

      batch_lock.synchronize do
        batch_results << {batch_id, successful, errors.first?}
      end
    rescue ex
      batch_lock.synchronize do
        batch_results << {batch_id, 0, ex.message}
      end
    end
    channel.send(nil)
  end
end

10.times { channel.receive }

total_inserted = batch_results.sum { |_, count, _| count }
expected_total = 2000

puts "Expected inserts: #{expected_total}"
puts "Actual inserts: #{total_inserted}"
puts "Success rate: #{(total_inserted.to_f / expected_total * 100).round(2)}%"

if total_inserted < expected_total
  puts "\nBatch failures:"
  batch_results.select { |_, count, _| count < 200 }.each do |batch_id, count, error|
    puts "  Batch #{batch_id}: #{count}/200 inserted"
    puts "    Error: #{error}" if error
  end
end

# Test 3: Connection pool exhaustion
puts "\n3. Testing connection pool limits"
puts "Testing with 50 concurrent connections..."

channel = Channel(Nil).new
pool_results = [] of {Int32, Bool, Float64, String?}
pool_lock = Mutex.new

start_time = Time.local

50.times do |conn_id|
  spawn do
    conn_start = Time.local
    begin
      # Simulate a longer operation
      model = Crecto::LoadTesting::LoadTestModel.new
      model.name = "Pool Test #{conn_id}"
      model.value = conn_id
      model.created_at = Time.local

      result = Crecto::LoadTesting::TestRepo.insert(model)

      # Simulate some processing time
      sleep(0.001)

      conn_time = Time.local - conn_start
      pool_lock.synchronize do
        pool_results << {conn_id, true, conn_time.total_seconds, nil}
      end
    rescue ex
      conn_time = Time.local - conn_start
      pool_lock.synchronize do
        pool_results << {conn_id, false, conn_time.total_seconds, ex.message}
      end
    end
    channel.send(nil)
  end
end

50.times { channel.receive }

end_time = Time.local
total_time = end_time - start_time

pool_success = pool_results.count { |_, success, _, _| success }
pool_failures = pool_results.count { |_, success, _, _| !success }
avg_time = pool_results.map { |_, _, time, _| time }.sum / pool_results.size

puts "Total time: #{total_time.total_seconds.round(3)}s"
puts "Successful connections: #{pool_success}/50"
puts "Failed connections: #{pool_failures}/50"
puts "Average operation time: #{(avg_time * 1000).round(2)}ms"

if pool_failures > 0
  puts "\nConnection failures:"
  pool_results.select { |_, success, _, _| !success }.first(5).each do |conn_id, _, time, error|
    puts "  Conn #{conn_id}: #{error} (after #{(time * 1000).round(2)}ms)"
  end
end

# Test 4: SQLite WAL mode vs DELETE mode
puts "\n4. Testing SQLite journal modes"

# Check current journal mode
current_mode = Crecto::LoadTesting::TestRepo.raw_scalar("PRAGMA journal_mode")
puts "Current journal mode: #{current_mode}"

# Try WAL mode if not already
if current_mode.to_s.downcase != "wal"
  puts "Trying to enable WAL mode..."
  begin
    Crecto::LoadTesting::TestRepo.raw_exec("PRAGMA journal_mode=WAL")
    puts "WAL mode enabled successfully"
  rescue ex
    puts "Failed to enable WAL mode: #{ex.message}"
  end
end

# Run a quick performance test with WAL mode
puts "Running performance test with current journal mode..."

wal_start = Time.local
50.times do |i|
  model = Crecto::LoadTesting::LoadTestModel.new
  model.name = "WAL Test #{i}"
  model.value = i
  model.created_at = Time.local
  Crecto::LoadTesting::TestRepo.insert(model)
end
wal_time = Time.local - wal_start

puts "50 inserts took: #{wal_time.total_seconds.round(3)}s"
puts "Ops/sec: #{(50 / wal_time.total_seconds).round(2)}"

# Check database file size
db_file = "./spec/load/load_test.db"
if File.exists?(db_file)
  size = File.size(db_file)
  puts "Database file size: #{(size / 1024.0).round(2)} KB"
end

cleanup_test_database
puts "\nTest completed!"