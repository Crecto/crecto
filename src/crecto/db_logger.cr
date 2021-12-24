require "log"
require "colorize"

module Crecto
  module DbLogger
    @@log_handler : IO? | Log?
    @@tty = true

    def self.log(string, elapsed) : Nil
      if handler = @@log_handler
        if handler.is_a?(Log)
          handler.as(Log).info {"#{("%7.7s" % elapsed_text(elapsed)).colorize(:magenta)} #{string.colorize(:blue)}" }
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
      params.each do |param|
        string = string.sub(/(\$\d+|\?)/, "'#{param}'")
      end
      log(string, elapsed)
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

    private def self.elapsed_text(elapsed) : String
      minutes = elapsed.total_minutes
      return "#{minutes.round(2)}m" if minutes >= 1

      seconds = elapsed.total_seconds
      return "#{seconds.round(2)}s" if seconds >= 1

      millis = elapsed.total_milliseconds
      return "#{millis.round(2)}ms" if millis >= 1

      "#{(millis * 1000).round(2)}µs"
    end
  end
end
