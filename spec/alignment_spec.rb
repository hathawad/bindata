#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

describe BinData::ResumeByteAlignment do
  class ResumeAlignmentRecord < BinData::Record
    bit4 :a
    resume_byte_alignment
    bit4 :b
  end

  subject { ResumeAlignmentRecord.new }

  it "should reset read alignment" do
    subject.read "\x12\x34"

    subject.a.should == 1
    subject.b.should == 3
  end

  it "should reset write alignment" do
    subject.assign(:a => 2, :b => 7)

    subject.to_binary_s.should == "\x20\x70"
  end
end

describe BinData::BitAligned do
  it "should not apply to BinData::Primitives" do
    lambda {
      class BitAlignedPrimitive < BinData::Primitive
        bit_aligned
      end
    }.should raise_error
  end

  class BitString < BinData::String
    bit_aligned
  end

  class BitAlignedRecord < BinData::Record
    bit4 :preamble
    bit_string :str, :length => 2
    bit4 :afterward
  end

  subject { BitAlignedRecord.new }

  its(:num_bytes) { should == 3 }

  it "should read" do
    subject.read("\x56\x36\x42")
    subject.should == {"preamble" => 5, "str" => "cd", "afterward" => 2}
  end

  it "should write" do
    subject.assign(:preamble => 5, :str => "ab", :afterward => 1)
    subject.to_binary_s.should == "\x56\x16\x21"
  end
end
