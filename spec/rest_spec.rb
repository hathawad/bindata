#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/rest'

describe BinData::Rest do
  it { should == "" }

  it "should read till end of stream" do
    data = "abcdefghij"
    subject.read(data).should == data
  end

  it "should allow setting value for completeness" do
    subject.assign("123")
    subject.should == "123"
    subject.to_binary_s.should == "123"
  end

  it "should accept BinData::BasePrimitive parameters" do
    rest = BinData::Rest.new(:check_value => "abc")
    lambda {
      rest.read("xyz")
    }.should raise_error(BinData::ValidityError)
  end
end
