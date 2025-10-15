require "log"
require "colorize"

module Crecto
  module DbLogger
    @@log_handler : IO? | Log?
    @@tty = true

    def self.log(string, elapsed) : Nil
      if handler = @@log_handler
        if handler.is_a?(Log)
          handler.as(Log).info { "#{("%7.7s" % elapsed_text(elapsed)).colorize(:magenta)} #{string.colorize(:blue)}" }
        else
          handler.as(IO) << if @@tty
            "#{("%7.7s" % elapsed_text(elapsed)).colorize(:magenta)} #{string.colorize(:blue)}\n"
          else
            "#{"%7.7s" % elapsed_text(elapsed)} #{string}\n"
          end
        end
      end
    end

    def self.log(string, elapsed, params) : Nil
      # Sanitize parameters to prevent SQL injection in logs
      sanitized_params = params.map do |param|
        # Escape single quotes and limit parameter length for security
        sanitized = param.to_s.gsub("'", "''")
        sanitized.size > 100 ? "#{sanitized[0, 97]}..." : sanitized
      end

      # Create a safe representation of the query with parameters
      safe_string = string.dup
      sanitized_params.each do |param|
        safe_string = safe_string.sub(/(\$\d+|\?)/, "'#{param}'")
      end

      log(safe_string, elapsed)
    end

    def self.set_handler(logger : Log)
      @@log_handler = logger
      @@log_handler.as(Log).level = Log::Severity::Info
    end

    def self.set_handler(io : IO)
      @@log_handler = io
      @@tty = @@log_handler.not_nil!.as(IO).tty?
    end

    def self.unset_handler
      @@log_handler = nil
      @@tty = true
    end

    def self.log_error(error_type : String, message : String, context : Hash(String, String | Int32 | Bool | Array(String))? = nil) : Nil
      error_msg = "[#{error_type}] #{message}"
      if context && !context.empty?
        context_str = context.map { |k, v|
          if v.is_a?(Array)
            "#{k}=#{v.as(Array).join(",")}"
          else
            "#{k}=#{v}"
          end
        }.join(", ")
        error_msg += " | Context: #{context_str}"
      end

      if handler = @@log_handler
        if handler.is_a?(Log)
          handler.as(Log).error { error_msg.colorize(:red) }
        else
          handler.as(IO) << if @@tty
            "#{error_msg.colorize(:red)}\n"
          else
            "#{error_msg}\n"
          end
        end
      end
    end

    private def self.elapsed_text(elapsed) : String
      minutes = elapsed.total_minutes
      return "#{minutes.round(2)}m" if minutes >= 1

      seconds = elapsed.total_seconds
      return "#{seconds.round(2)}s" if seconds >= 1

      millis = elapsed.total_milliseconds
      if millis >= 1
        # Keep milliseconds as integer if it's a whole number
        return millis == millis.to_i ? "#{millis.to_i}ms" : "#{millis.round(2)}ms"
      end

      micros = millis * 1000
      return "#{micros.to_i}µs" if micros == micros.to_i
      "#{micros.round(2)}µs"
    end
  end
end
