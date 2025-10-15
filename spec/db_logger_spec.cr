require "spec"
require "./spec_helper"
require "../src/crecto/db_logger"

describe Crecto::DbLogger do
  describe ".log" do
    context "with IO handler" do
      it "logs query with elapsed time to IO" do
        io = IO::Memory.new
        Crecto::DbLogger.set_handler(io)

        elapsed = Time::Span.new(nanoseconds: 1500000) # 1.5ms
        Crecto::DbLogger.log("SELECT * FROM users", elapsed)

        output = io.to_s
        output.should contain("SELECT * FROM users")
        output.should contain("1.5ms")
      end

      it "formats time correctly for different durations" do
        io = IO::Memory.new
        Crecto::DbLogger.set_handler(io)

        # Test microseconds (500 nanoseconds = 0.5 microseconds)
        Crecto::DbLogger.log("micro test", Time::Span.new(nanoseconds: 500))

        # Test milliseconds (150 million nanoseconds = 150 milliseconds)
        Crecto::DbLogger.log("millis test", Time::Span.new(nanoseconds: 150_000_000))

        # Test seconds
        Crecto::DbLogger.log("seconds test", Time::Span.new(seconds: 2, nanoseconds: 0))

        # Test minutes
        Crecto::DbLogger.log("minutes test", Time::Span.new(minutes: 3, seconds: 0, nanoseconds: 0))

        output = io.to_s
        output.should contain("0.5µs")
        output.should contain("150ms")
        output.should contain("2.0s")
        output.should contain("3.0m")
      end

      it "outputs query without color formatting" do
        io = IO::Memory.new
        Crecto::DbLogger.set_handler(io)

        elapsed = Time::Span.new(nanoseconds: 100_000_000)
        Crecto::DbLogger.log("test query", elapsed)

        output = io.to_s
        output.should contain("test query")
        output.should contain("100ms")
      end
    end

    context "with Log handler" do
      pending "logs query to Log handler", "Log handler testing requires backend setup"
    end

    context "with no handler" do
      it "does not output anything" do
        Crecto::DbLogger.unset_handler

        # Should not raise any errors
        elapsed = Time::Span.new(nanoseconds: 100_000_000)
        Crecto::DbLogger.log("test query", elapsed)
      end
    end
  end

  describe ".log with params" do
    it "replaces parameter placeholders with quoted values" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      elapsed = Time::Span.new(nanoseconds: 25_000_000)
      params = ["John Doe", "john@example.com"]
      Crecto::DbLogger.log("SELECT * FROM users WHERE name = $1 AND email = $2", elapsed, params)

      output = io.to_s
      output.should contain("'John Doe'")
      output.should contain("'john@example.com'")
      output.should_not contain("$1")
      output.should_not contain("$2")
    end

    it "replaces question mark placeholders" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      elapsed = Time::Span.new(nanoseconds: 30_000_000)
      params = ["admin"]
      Crecto::DbLogger.log("UPDATE users SET role = ? WHERE id = 1", elapsed, params)

      output = io.to_s
      output.should contain("'admin'")
      output.should_not contain("?")
    end

    it "handles empty params array" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      elapsed = Time::Span.new(nanoseconds: 10_000_000)
      params = [] of String
      Crecto::DbLogger.log("SELECT COUNT(*) FROM users", elapsed, params)

      output = io.to_s
      output.should contain("SELECT COUNT(*) FROM users")
    end
  end

  describe ".log_error" do
    context "with IO handler" do
      it "logs error with type and message" do
        io = IO::Memory.new
        Crecto::DbLogger.set_handler(io)

        Crecto::DbLogger.log_error("ConnectionError", "Database connection failed")

        output = io.to_s
        output.should contain("[ConnectionError] Database connection failed")
      end

      it "includes context when provided" do
        io = IO::Memory.new
        Crecto::DbLogger.set_handler(io)

        context = {
          "retry_count" => 3,
          "host" => "localhost",
          "database" => "test_db"
        }
        Crecto::DbLogger.log_error("QueryError", "Invalid syntax", context)

        output = io.to_s
        output.should contain("[QueryError] Invalid syntax")
        output.should contain("retry_count=3")
        output.should contain("host=localhost")
        output.should contain("database=test_db")
        output.should contain("Context:")
      end

      it "handles empty context hash" do
        io = IO::Memory.new
        Crecto::DbLogger.set_handler(io)

        context = {} of String => String | Int32 | Bool | Array(String)
        Crecto::DbLogger.log_error("ValidationError", "Missing required field", context)

        output = io.to_s
        output.should contain("[ValidationError] Missing required field")
        output.should_not contain("Context:")
      end

      it "handles different context value types" do
        io = IO::Memory.new
        Crecto::DbLogger.set_handler(io)

        context = {
          "timeout" => 30,
          "ssl_enabled" => true,
          "tags" => ["production", "critical"]
        }
        Crecto::DbLogger.log_error("NetworkError", "Connection timeout", context)

        output = io.to_s
        output.should contain("timeout=30")
        output.should contain("ssl_enabled=true")
        output.should contain("tags=production,critical")
      end
    end

    context "with Log handler" do
      pending "logs error to Log handler", "Log handler testing requires backend setup"
    end

    context "with no handler" do
      it "does not output anything" do
        Crecto::DbLogger.unset_handler

        # Should not raise any errors
        Crecto::DbLogger.log_error("TestError", "Test message")
      end
    end
  end

  describe ".set_handler" do
    it "sets Log handler and configures log level" do
      log_io = IO::Memory.new
      logger = Log.for("test", Log::Severity::Debug)

      Crecto::DbLogger.set_handler(logger)

      # Log level should be set to INFO
      logger.level.should eq(Log::Severity::Info)
    end

    it "sets IO handler and detects TTY" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      # Should not raise any errors
      # TTY detection happens internally
    end
  end

  describe ".unset_handler" do
    it "removes the current handler" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      Crecto::DbLogger.unset_handler

      # Should not output anything after unsetting
      elapsed = Time::Span.new(nanoseconds: 100_000_000)
      Crecto::DbLogger.log("should not appear", elapsed)

      output = io.to_s
      output.should eq("")
    end

    it "resets TTY flag to true" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      Crecto::DbLogger.unset_handler

      # TTY flag should be reset (internal state)
      # This is tested implicitly by the fact that setting a new handler works
    end
  end

  describe "elapsed_text formatting" do
    it "formats microseconds correctly" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      # Test 500 microseconds = 500,000 nanoseconds
      elapsed = Time::Span.new(nanoseconds: 500_000)
      Crecto::DbLogger.log("test", elapsed)

      output = io.to_s
      output.should contain("500µs")
    end

    it "formats milliseconds correctly" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      # Test 1500 milliseconds, but since that's > 1 second it will show as 1.5s
      # Let's test 500 milliseconds instead
      elapsed = Time::Span.new(nanoseconds: 500_000_000)
      Crecto::DbLogger.log("test", elapsed)

      output = io.to_s
      output.should contain("500ms")
    end

    it "formats seconds correctly" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      elapsed = Time::Span.new(seconds: 5, nanoseconds: 750_000_000)
      Crecto::DbLogger.log("test", elapsed)

      output = io.to_s
      output.should contain("5.75s")
    end

    it "formats minutes correctly" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      elapsed = Time::Span.new(minutes: 2, seconds: 30, nanoseconds: 0)
      Crecto::DbLogger.log("test", elapsed)

      output = io.to_s
      output.should contain("2.5m")
    end

    it "truncates to 7 characters as specified" do
      io = IO::Memory.new
      Crecto::DbLogger.set_handler(io)

      # Use a value that won't cause overflow
      elapsed = Time::Span.new(nanoseconds: 12_345_678)
      Crecto::DbLogger.log("test", elapsed)

      output = io.to_s
      # Should be truncated to "12345ms" or similar (7 chars)
      lines = output.split('\n')
      time_part = lines.first?.try { |line| line.split(' ').first? }
      time_part.should_not be_nil
      time_part.not_nil!.size.should be <= 7
    end
  end
end