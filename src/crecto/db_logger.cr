module Crecto
  module DbLogger
    @@log_handler : IO?

    def self.log(string, elapsed) : Nil
      return if @@log_handler.nil?
      @@log_handler.not_nil! << "\e[36m#{"%7.7s" % elapsed_text(elapsed)} \e[34m#{string}\e[0m\n"
    end

    def self.log(string, elapsed, params) : Nil
      return if @@log_handler.nil?
      params.each do |param|
        string = string.sub(/(\$\d+|\?)/, "'#{param}'")
      end
      log(string, elapsed)
    end

    def self.set_handler(io : IO)
      @@log_handler = io
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
