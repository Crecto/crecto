#!/usr/bin/env crystal

require "json"
require "file_utils"

# Check for performance regressions compared to baseline

struct PerformanceBaseline
  property operation : String
  property ops_per_second : Float64
  property average_time_ms : Float64
  property max_time_ms : Float64
  property memory_usage_mb : Float64?

  def initialize(@operation, @ops_per_second, @average_time_ms, @max_time_ms, @memory_usage_mb = nil)
  end
end

struct PerformanceComparison
  property operation : String
  property baseline : PerformanceBaseline
  property current : PerformanceBaseline
  property ops_percent_change : Float64
  property time_percent_change : Float64
  property regression_detected : Bool

  def initialize(@operation, @baseline, @current)
    @ops_percent_change = ((@current.ops_per_second - @baseline.ops_per_second) / @baseline.ops_per_second * 100).round(2)
    @time_percent_change = ((@current.average_time_ms - @baseline.average_time_ms) / @baseline.average_time_ms * 100).round(2)
    @regression_detected = @ops_percent_change < -10.0 || @time_percent_change > 20.0
  end

  def to_s
    status = @regression_detected ? "🚨 REGRESSION" : "✅ OK"
    "#{@operation}: #{status} (ops: #{@ops_percent_change}%, time: #{@time_percent_change}%)"
  end
end

def load_baseline(file_path : String) : Hash(String, PerformanceBaseline)
  baselines = Hash(String, PerformanceBaseline).new

  if File.exists?(file_path)
    begin
      content = File.read(file_path)
      json = JSON.parse(content)

      json.as_h.each do |operation, data|
        ops_per_sec = data["operations_per_second"]?.try(&.as_f) || 0.0
        avg_time = data["average_time_ms"]?.try(&.as_f) || 0.0
        max_time = data["max_time_ms"]?.try(&.as_f) || 0.0
        memory = data["memory_usage_mb"]?.try(&.as_f)

        baselines[operation.to_s] = PerformanceBaseline.new(operation.to_s, ops_per_sec, avg_time, max_time, memory)
      end
    rescue ex
      puts "Error loading baseline: #{ex.message}"
    end
  end

  baselines
end

def load_current_results(directory : String) : Hash(String, PerformanceBaseline)
  current = Hash(String, PerformanceBaseline).new

  Dir.glob("#{directory}/results_*.json").each do |file|
    begin
      content = File.read(file)
      json = JSON.parse(content)

      if json.as_a?
        json.as_a.each do |result|
          if result["operations_per_second"]?
            operation = result["name"]?.as_s || "unknown"
            ops_per_sec = result["operations_per_second"].as_f
            avg_time = result["average_time_ms"]?.as_f || 0.0
            max_time = result["max_time_ms"]?.as_f || 0.0
            memory = result["memory_usage_mb"]?.try(&.as_f)

            current[operation] = PerformanceBaseline.new(operation, ops_per_sec, avg_time, max_time, memory)
          end
        end
      end
    rescue ex
      puts "Error parsing current results: #{ex.message}"
    end
  end

  current
end

def compare_performance(baselines : Hash(String, PerformanceBaseline), current : Hash(String, PerformanceBaseline)) : Array(PerformanceComparison)
  comparisons = Array(PerformanceComparison).new

  baselines.each do |operation, baseline|
    if current_result = current[operation]?
      comparison = PerformanceComparison.new(operation, baseline, current_result)
      comparisons << comparison
    end
  end

  comparisons
end

def generate_regression_report(comparisons : Array(PerformanceComparison)) : String
  regressions = comparisons.select(&.regression_detected)
  improvements = comparisons.select { |c| !c.regression_detected && c.ops_percent_change > 5.0 }

  report = String.build do |str|
    str << "# 🚨 Performance Regression Report\n\n"
    str << "Generated on: #{Time.utc}\n\n"

    if regressions.empty?
      str << "## ✅ No Performance Regressions Detected\n\n"
      str << "All performance metrics are within acceptable thresholds.\n\n"
    else
      str << "## 🚨 Performance Regressions Found (#{regressions.size})\n\n"

      regressions.each do |regression|
        str << "### #{regression.operation}\n"
        str << "- **Ops/sec Change**: #{regression.ops_percent_change}% (#{regression.baseline.ops_per_second.round(2)} → #{regression.current.ops_per_second.round(2)})\n"
        str << "- **Response Time Change**: #{regression.time_percent_change}% (#{regression.baseline.average_time_ms.round(2)}ms → #{regression.current.average_time_ms.round(2)}ms)\n"
        str << "- **Status**: 🚨 REGRESSION DETECTED\n\n"
      end
    end

    if improvements.any?
      str << "## 📈 Performance Improvements\n\n"

      improvements.each do |improvement|
        str << "### #{improvement.operation}\n"
        str << "- **Ops/sec Improvement**: +#{improvement.ops_percent_change}% (#{improvement.baseline.ops_per_second.round(2)} → #{improvement.current.ops_per_second.round(2)})\n"
        str << "- **Response Time Change**: #{improvement.time_percent_change}% (#{improvement.baseline.average_time_ms.round(2)}ms → #{improvement.current.average_time_ms.round(2)}ms)\n"
        str << "- **Status**: ✅ IMPROVEMENT\n\n"
      end
    end

    str << "## 📊 Summary\n\n"
    str << "- **Total Operations Compared**: #{comparisons.size}\n"
    str << "- **Regressions**: #{regressions.size}\n"
    str << "- **Improvements**: #{improvements.size}\n"
    str << "- **No Change**: #{comparisons.size - regressions.size - improvements.size}\n"

    if regressions.any?
      str << "\n## 🎯 Recommendations\n\n"
      str << "1. Review the regressed operations for potential bottlenecks\n"
      str << "2. Consider performance optimizations before merging\n"
      str << "3. If regressions are acceptable, update performance baselines\n"
    end
  end

  report
end

def main
  puts "🔍 Checking for performance regressions..."

  # Find the most recent baseline file
  baseline_files = Dir.glob("spec/performance/baseline_*.json").sort.reverse
  if baseline_files.empty?
    puts "⚠️  No baseline files found. Cannot check for regressions."
    exit 0
  end

  baseline_file = baseline_files.first
  puts "📊 Using baseline: #{baseline_file}"

  # Load baseline and current results
  baselines = load_baseline(baseline_file)
  current_results = load_current_results("artifacts/performance-results")

  if baselines.empty?
    puts "⚠️  No baseline data loaded."
    exit 0
  end

  if current_results.empty?
    puts "⚠️  No current performance results found."
    exit 0
  end

  # Compare performance
  comparisons = compare_performance(baselines, current_results)

  # Generate report
  report = generate_regression_report(comparisons)
  File.write("performance-regression-report.md", report)

  # Check for regressions and exit accordingly
  regressions = comparisons.select(&.regression_detected)

  puts "\n" + report

  if regressions.any?
    puts "\n❌ Performance regressions detected!"
    puts "📄 Full report: performance-regression-report.md"
    exit 1
  else
    puts "\n✅ No performance regressions detected!"
    exit 0
  end
end

# Run the script
main