#!/usr/bin/env crystal
require "./spec/load/load_test_helper"
require "./spec/load/crud_load_test_spec"

# Script to reproduce the specific load test failures mentioned

puts "Reproducing Load Test Failures"
puts "=" * 50

# Test the exact scenarios from the load tests

# Test 1: High-Volume Inserts (2000 inserts, 10 workers)
puts "\n1. High-Volume Inserts Test (2000 inserts, 10 workers)"
config = Crecto::LoadTesting::Config.new(
  operation_counts: {"insert" => 2000},
  concurrent_workers: 10
)

runner = CRUDLoadTestRunner.new(config)
stats = runner.run_load_test("High-Volume Inserts Reproduction")

puts "Success Rate: #{stats.success_rate}%"
puts "Ops/sec: #{stats.operations_per_second}"
puts "Failed Operations: #{stats.failed_operations}"

# Show actual error messages
if stats.errors.any?
  puts "\nFirst 10 errors:"
  stats.errors.first(10).each_with_index do |error, i|
    puts "  #{i + 1}. #{error}"
  end
end

# Test 2: Basic CRUD with 5 workers
puts "\n" + "=" * 50
puts "\n2. Basic CRUD Test (5 workers, 2250 operations)"
config2 = Crecto::LoadTesting::Config.new(
  operation_counts: {
    "insert" => 500,
    "update" => 500,
    "delete" => 250,
    "query" => 1000
  },
  concurrent_workers: 5
)

runner2 = CRUDLoadTestRunner.new(config2)
stats2 = runner2.run_load_test("Basic CRUD Reproduction")

puts "Success Rate: #{stats2.success_rate}%"
puts "Ops/sec: #{stats2.operations_per_second}"
puts "Failed Operations: #{stats2.failed_operations}"

# Show errors if any
if stats2.errors.any?
  puts "\nFirst 10 errors:"
  stats2.errors.first(10).each_with_index do |error, i|
    puts "  #{i + 1}. #{error}"
  end
end

cleanup_test_database
puts "\nDone!"