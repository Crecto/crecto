#
# 	Override crystal-pg `self.drivers` be public so we can see which driver is being used
#
module DB
  def self.drivers
    @@drivers ||= {} of String => Driver.class
  end

  class Database
  end
end
