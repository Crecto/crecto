#!/usr/bin/env crystal
require "./spec/load/load_test_helper"
require "./spec/load/optimized_load_test_helper"

# Compare original vs optimized load test performance

puts "Crecto Load Test Performance Comparison"
puts "=" * 60

# Test configuration
test_scenarios = [
  {
    name: "Basic CRUD Test",
    operations: {
      "insert" => 500,
      "update" => 500,
      "query" => 1000,
      "delete" => 250
    },
    workers: 5
  },
  {
    name: "High-Volume Inserts",
    operations: {"insert" => 2000},
    workers: 10
  },
  {
    name: "Concurrent Operations",
    operations: {"query" => 5000},
    workers: 15
  }
]

test_scenarios.each do |scenario|
  puts "\n#{scenario[:name]}"
  puts "-" * 40

  # Test original implementation
  puts "\n[Original Implementation]"
  setup_test_database

  original_config = Crecto::LoadTesting::Config.new(
    operation_counts: scenario[:operations],
    concurrent_workers: scenario[:workers]
  )

  original_runner = Crecto::LoadTesting::Runner.new(original_config)
  original_stats = original_runner.run_load_test("Original #{scenario[:name]}")

  cleanup_test_database

  # Test optimized implementation
  puts "\n[Optimized Implementation]"
  setup_optimized_test_database

  optimized_config = Crecto::LoadTesting::OptimizedConfig.new(
    operation_counts: scenario[:operations],
    concurrent_workers: scenario[:workers]
  )
  optimized_config.use_transactions = true
  optimized_config.transaction_batch_size = 100
  optimized_config.enable_retry = true

  optimized_runner = Crecto::LoadTesting::OptimizedRunner.new(optimized_config)
  optimized_stats = optimized_runner.run_load_test("Optimized #{scenario[:name]}")

  cleanup_optimized_test_database

  # Compare results
  puts "\n[Performance Comparison]"
  puts "Metric                  Original    Optimized    Improvement"
  puts "--------------------  ----------  ----------  ------------"

  # Success Rate
  orig_sr = original_stats.success_rate
  opt_sr = optimized_stats.success_rate
  sr_improvement = orig_sr > 0 ? ((opt_sr - orig_sr) / orig_sr * 100).round(2) : 0.0
  puts "Success Rate (%)         #{sprintf("%9.2f", orig_sr)}    #{sprintf("%9.2f", opt_sr)}    #{sprintf("%10.2f%%", sr_improvement)}"

  # Operations per Second
  orig_ops = original_stats.operations_per_second
  opt_ops = optimized_stats.operations_per_second
  ops_improvement = orig_ops > 0 ? ((opt_ops - orig_ops) / orig_ops * 100).round(2) : 0.0
  puts "Operations/Second        #{sprintf("%9.2f", orig_ops)}    #{sprintf("%9.2f", opt_ops)}    #{sprintf("%10.2f%%", ops_improvement)}"

  # Failed Operations
  puts "Failed Operations        #{sprintf("%9d", original_stats.failed_operations)}    #{sprintf("%9d", optimized_stats.failed_operations)}    #{sprintf("%10s", "N/A")}"

  # Memory Usage
  orig_mem = original_stats.memory_usage_mb
  opt_mem = optimized_stats.memory_usage_mb
  mem_change = orig_mem > 0 ? ((opt_mem - orig_mem) / orig_mem * 100).round(2) : 0.0
  mem_indicator = mem_change.abs < 5 ? "~" : (mem_change > 0 ? "+" : "-")
  puts "Memory Usage (MB)       #{sprintf("%9.2f", orig_mem)}    #{sprintf("%9.2f", opt_mem)}    #{sprintf("%10s", "#{mem_indicator}#{mem_change.abs.round(2)}%")}"

  # Time
  puts "Total Time (s)          #{sprintf("%9.3f", original_stats.total_time.total_seconds)}    #{sprintf("%9.3f", optimized_stats.total_time.total_seconds)}    #{sprintf("%10s", "N/A")}"

  # Summary
  puts "\n[Summary]"
  if sr_improvement > 0
    puts "✓ Success rate improved by #{sr_improvement}%"
  elsif sr_improvement < 0
    puts "✗ Success rate decreased by #{sr_improvement.abs}%"
  end

  if ops_improvement > 0
    puts "✓ Throughput improved by #{ops_improvement}%"
  elsif ops_improvement < 0
    puts "✗ Throughput decreased by #{ops_improvement.abs}%"
  end

  if optimized_stats.failed_operations < original_stats.failed_operations
    puts "✓ Fewer failed operations (#{original_stats.failed_operations - optimized_stats.failed_operations} fewer)"
  elsif optimized_stats.failed_operations > original_stats.failed_operations
    puts "✗ More failed operations (#{optimized_stats.failed_operations - original_stats.failed_operations} more)"
  end
end

puts "\n" + "=" * 60
puts "Comparison completed!"
puts "\nKey Optimizations Applied:"
puts "- WAL journal mode for better concurrency"
puts "- Connection pool optimization (10 initial, 50 max)"
puts "- Transaction batching for high-volume operations"
puts "- Retry logic with exponential backoff"
puts "- Adaptive batch sizing based on success rates"
puts "- SQLite-specific PRAGMA optimizations"