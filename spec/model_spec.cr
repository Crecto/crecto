require "./spec_helper"

describe Crecto::Model do
  context "json: " do
    it "can be instatiated from json" do
      user = User.from_json(%|{"name":"test"}|)
      user.name.should eq("test")
    end

    it "sets default values" do
      model = DefaultValue.from_json(%|{"default_string":"overridden"}|)
      model.default_string.should eq("overridden")
      model.default_int.should eq(64)
    end
  end
end
