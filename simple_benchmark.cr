#!/usr/bin/env crystal
require "./spec/load/load_test_helper"

# Simple benchmark to test SQLite performance under load

puts "SQLite Performance Benchmark"
puts "=" * 50

# Setup database
setup_test_database

# Test 1: Sequential inserts
puts "\n1. Sequential Inserts (1000 records)"
start = Time.local
1000.times do |i|
  model = Crecto::LoadTesting::LoadTestModel.new
  model.name = "Test #{i}"
  model.value = i
  model.created_at = Time.local
  Crecto::LoadTesting::TestRepo.insert(model)
end
time1 = Time.local - start
puts "Time: #{time1.total_seconds.round(3)}s"
puts "Ops/sec: #{(1000 / time1.total_seconds).round(2)}"

# Clean up
Crecto::LoadTesting::TestRepo.raw_exec("DELETE FROM load_test_models")

# Test 2: Batch inserts with transaction
puts "\n2. Batch Inserts with Transaction (1000 records)"
start = Time.local
Crecto::LoadTesting::TestRepo.transaction! do |tx|
  1000.times do |i|
    model = Crecto::LoadTesting::LoadTestModel.new
    model.name = "Batch Test #{i}"
    model.value = i
    model.created_at = Time.local
    tx.insert!(model)
  end
end
time2 = Time.local - start
puts "Time: #{time2.total_seconds.round(3)}s"
puts "Ops/sec: #{(1000 / time2.total_seconds).round(2)}"

# Test 3: Concurrent inserts
puts "\n3. Concurrent Inserts (10 threads x 100 inserts = 1000)"
channel = Channel(Nil).new
errors = [] of Exception
errors_lock = Mutex.new

start = Time.local
10.times do |thread_id|
  spawn do
    begin
      100.times do |i|
        model = Crecto::LoadTesting::LoadTestModel.new
        model.name = "Concurrent #{thread_id}-#{i}"
        model.value = thread_id * 100 + i
        model.created_at = Time.local
        Crecto::LoadTesting::TestRepo.insert(model)
      end
    rescue ex
      errors_lock.synchronize do
        errors << ex
      end
    end
    channel.send(nil)
  end
end

10.times { channel.receive }
time3 = Time.local - start
puts "Time: #{time3.total_seconds.round(3)}s"
puts "Ops/sec: #{(1000 / time3.total_seconds).round(2)}"
puts "Errors: #{errors.size}"
if errors.any?
  puts "First error: #{errors.first.message}"
end

# Test 4: Check connection limits
puts "\n4. Connection Stress Test (100 concurrent threads)"
channel = Channel(Nil).new
success = 0
error_count = 0
count_lock = Mutex.new

start = Time.local
100.times do |i|
  spawn do
    begin
      model = Crecto::LoadTesting::LoadTestModel.new
      model.name = "Stress Test #{i}"
      model.value = i
      model.created_at = Time.local
      Crecto::LoadTesting::TestRepo.insert(model)
      count_lock.synchronize { success += 1 }
    rescue ex
      count_lock.synchronize { error_count += 1 }
      puts "Thread #{i} error: #{ex.message}" if i < 5
    end
    channel.send(nil)
  end
end

100.times { channel.receive }
time4 = Time.local - start
puts "Time: #{time4.total_seconds.round(3)}s"
puts "Successful: #{success}/100"
puts "Failed: #{error_count}/100"
puts "Ops/sec: #{(success / time4.total_seconds).round(2)}"

# Final count
count = Crecto::LoadTesting::TestRepo.aggregate(
  Crecto::LoadTesting::LoadTestModel,
  :count,
  :id
)
puts "\nTotal records in database: #{count}"

cleanup_test_database
puts "\nBenchmark completed!"