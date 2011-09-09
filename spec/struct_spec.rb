#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

describe BinData::Struct, "when initializing" do
  it "should fail on non registered types" do
    params = {:fields => [[:non_registered_type, :a]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(BinData::UnRegisteredTypeError)
  end

  it "should fail on duplicate names" do
    params = {:fields => [[:int8, :a], [:int8, :b], [:int8, :a]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(NameError)
  end

  it "should fail on reserved names" do
    # note that #invert is from Hash.instance_methods
    params = {:fields => [[:int8, :a], [:int8, :invert]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(NameError)
  end

  it "should fail when field name shadows an existing method" do
    params = {:fields => [[:int8, :object_id]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(NameError)
  end

  it "should fail on unknown endian" do
    params = {:endian => 'bad value', :fields => []}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(ArgumentError)
  end
end

describe BinData::Struct, "with anonymous fields" do
  subject {
    params = { :fields => [
                            [:int8, :a, {:initial_value => 5}],
                            [:int8, nil],
                            [:int8, '', {:value => :a}]
                          ] }
    BinData::Struct.new(params)
  }

  it "should only show non anonymous fields" do
    subject.field_names.should == ["a"]
  end

  it "should not include anonymous fields in snapshot" do
    subject.a = 5
    subject.snapshot.should == {"a" => 5}
  end

  it "should write anonymous fields" do
    subject.read("\001\002\003")
    subject.a.clear
    subject.to_binary_s.should == "\005\002\005"
  end
end

describe BinData::Struct, "with hidden fields" do
  subject {
    params = { :hide => [:b, :c],
               :fields => [
                   [:int8, :a],
                   [:int8, 'b', {:initial_value => 5}],
                   [:int8, :c],
                   [:int8, :d, {:value => :b}]] }
    BinData::Struct.new(params)
  }

  it "should only show fields that aren't hidden" do
    subject.field_names.should == ["a", "d"]
  end

  it "should be able to access hidden fields directly" do
    subject.b.should == 5
    subject.c = 15
    subject.c.should == 15

    subject.should respond_to(:b=)
  end

  it "should not include hidden fields in snapshot" do
    subject.b = 7
    subject.snapshot.should == {"a" => 0, "d" => 7}
  end

  it "should detect hidden fields with has_key?" do
    subject.should have_key("b")
  end
end

describe BinData::Struct, "with multiple fields" do
  let(:params) { { :fields => [ [:int8, :a], [:int8, :b] ] } }
  subject { BinData::Struct.new({:a => 1, :b => 2}, params) }

  its(:field_names) { should == ["a", "b"] }
  its(:to_binary_s) { should == "\x01\x02" }

  it "should return num_bytes" do
    subject.a.num_bytes.should == 1
    subject.b.num_bytes.should == 1
    subject.num_bytes.should   == 2
  end

  it "should identify accepted parameters" do
    BinData::Struct.accepted_parameters.all.should include(:fields)
    BinData::Struct.accepted_parameters.all.should include(:hide)
    BinData::Struct.accepted_parameters.all.should include(:endian)
  end

  it "should clear" do
    subject.a = 6
    subject.clear
    subject.should be_clear
  end

  it "should clear individual elements" do
    subject.a = 6
    subject.b = 7
    subject.a.clear
    subject.a.should be_clear
    subject.b.should_not be_clear
  end

  it "should read elements dynamically" do
    subject[:a].should == 1
  end

  it "should write elements dynamically" do
    subject[:a] = 2
    subject.a.should == 2
  end

  it "should implement has_key?" do
    subject.should have_key("a")
  end

  it "should read ordered" do
    subject.read("\x03\x04")

    subject.a.should == 3
    subject.b.should == 4
  end

  it "should return a snapshot" do
    snap = subject.snapshot
    snap.a.should == 1
    snap.b.should == 2
    snap.should == { "a" => 1, "b" => 2 }
  end

  it "should assign from partial hash" do
    subject.assign("a" => 3)
    subject.a.should == 3
    subject.b.should == 0
  end

  it "should assign from hash" do
    subject.assign("a" => 3, "b" => 4)
    subject.a.should == 3
    subject.b.should == 4
  end

  it "should assign from nil" do
    subject.assign(nil)
    subject.should be_clear
  end

  it "should assign from Struct" do
    src = BinData::Struct.new(params)
    src.a = 3
    src.b = 4

    subject.assign(src)
    subject.a.should == 3
    subject.b.should == 4
  end

  it "should assign from snapshot" do
    src = BinData::Struct.new(params)
    src.a = 3
    src.b = 4

    subject.assign(src.snapshot)
    subject.a.should == 3
    subject.b.should == 4
  end

  it "should fail on unknown method call" do
    lambda { subject.does_not_exist }.should raise_error(NoMethodError)
  end

  context "#snapshot" do
    it "should have ordered #keys" do
      subject.snapshot.keys.should == ["a", "b"]
    end

    it "should have ordered #each" do
      keys = []
      subject.snapshot.each { |el| keys << el[0] }
      keys.should == ["a", "b"]
    end

    it "should have ordered #each_pair" do
      keys = []
      subject.snapshot.each_pair { |k, v| keys << k }
      keys.should == ["a", "b"]
    end
  end
end

describe BinData::Struct, "with nested structs" do
  subject {
    inner1 = [ [:int8, :w, {:initial_value => 3}],
               [:int8, :x, {:value => :the_val}] ]

    inner2 = [ [:int8, :y, {:value => lambda { parent.b.w }}],
               [:int8, :z] ]

    params = { :fields => [
                 [:int8, :a, {:initial_value => 6}],
                 [:struct, :b, {:fields => inner1, :the_val => :a}],
                 [:struct, :c, {:fields => inner2}]] }
    BinData::Struct.new(params)
  }

  its(:field_names) { should == ["a", "b", "c"] }

  it "should return num_bytes" do
    subject.b.num_bytes.should == 2
    subject.c.num_bytes.should == 2
    subject.num_bytes.should == 5
  end

  it "should access nested fields" do
    subject.a.should   == 6
    subject.b.w.should == 3
    subject.b.x.should == 6
    subject.c.y.should == 3
    subject.c.z.should == 0
  end

  it "should return correct offset" do
    subject.b.offset.should == 1
    subject.b.w.offset.should == 1
    subject.c.offset.should == 3
    subject.c.z.offset.should == 4
  end
end

describe BinData::Struct, "with an endian defined" do
  subject {
    BinData::Struct.new(:endian => :little,
                        :fields => [
                                     [:uint16, :a],
                                     [:float, :b],
                                     [:array, :c,
                                       {:type => :int8, :initial_length => 2}],
                                     [:choice, :d,
                                       {:choices => [[:uint16], [:uint32]],
                                        :selection => 1}],
                                     [:struct, :e,
                                       {:fields => [[:uint16, :f],
                                                    [:uint32be, :g]]}],
                                     [:struct, :h,
                                       {:fields => [
                                         [:struct, :i,
                                           {:fields => [[:uint16, :j]]}]]}]])
  }

  it "should use correct endian" do
    subject.a = 1
    subject.b = 2.0
    subject.c[0] = 3
    subject.c[1] = 4
    subject.d = 5
    subject.e.f = 6
    subject.e.g = 7
    subject.h.i.j = 8

    expected = [1, 2.0, 3, 4, 5, 6, 7, 8].pack('veCCVvNv')

    subject.to_binary_s.should == expected
  end
end

describe BinData::Struct, "with bit fields" do
  subject {
    params = { :fields => [ [:bit1le, :a], [:bit2le, :b], [:uint8, :c], [:bit1le, :d] ] }
    BinData::Struct.new({:a => 1, :b => 2, :c => 3, :d => 1}, params)
  }

  its(:num_bytes) { should == 3 }
  its(:to_binary_s) { should == [0b0000_0101, 3, 1].pack("C*") }

  it "should read" do
    str = [0b0000_0110, 5, 0].pack("C*")
    subject.read(str)
    subject.a.should == 0
    subject.b.should == 3
    subject.c.should == 5
    subject.d.should == 0
  end

  it "should have correct offsets" do
    subject.a.offset.should == 0
    subject.b.offset.should == 0
    subject.c.offset.should == 1
    subject.d.offset.should == 2
  end
end

describe BinData::Struct, "with nested endian" do
  it "should use correct endian" do
    nested_params = { :endian => :little,
                      :fields => [[:int16, :b], [:int16, :c]] }
    params = { :endian => :big, 
               :fields => [[:int16, :a],
                           [:struct, :s, nested_params],
                           [:int16, :d]] }
    subject = BinData::Struct.new(params)
    subject.read("\x00\x01\x02\x00\x03\x00\x00\x04")

    subject.a.should   == 1
    subject.s.b.should == 2
    subject.s.c.should == 3
    subject.d.should   == 4
  end
end
