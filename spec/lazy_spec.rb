#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/lazy'

# A mock data object with customizable fields.
class MockBinDataObject
  def initialize(methods = {}, params = {}, parent = nil)
    meta = class << self ; self; end
    methods.each do |k,v|
      meta.send(:define_method, k.to_sym) { v }
    end
    @parameters = params
    @parent = parent
  end
  attr_accessor :parent

  def has_parameter?(key)
    @parameters.has_key?(key)
  end

  def get_parameter(key)
    @parameters[key]
  end

  def lazy_evaluator
    BinData::LazyEvaluator.new(self)
  end
end

def lazy_eval(*rest)
  subject.lazy_evaluator.lazy_eval(*rest)
end

describe BinData::LazyEvaluator, "with no parents" do
  subject {
    methods = {:m1 => 'm1', :com => 'mC'}
    params  = {:p1 => 'p1', :com => 'pC'}
    MockBinDataObject.new(methods, params)
  }

  it "should evaluate raw value when instantiated" do
    lazy_eval(5).should == 5
  end

  it "should evaluate raw value" do
    lazy_eval(5).should == 5
  end

  it "should evaluate value" do
    lazy_eval(lambda { 5 }).should == 5
  end

  it "should evaluate overrides" do
    lazy_eval(lambda { o1 }, :o1 => 'o1').should == 'o1'
  end

  it "should not resolve any unknown methods" do
    lambda { lazy_eval(lambda { unknown }) }.should raise_error(NameError)
    lambda { lazy_eval(lambda { m1 }) }.should raise_error(NameError)
    lambda { lazy_eval(lambda { p1 }) }.should raise_error(NameError)
  end

  it "should not have a parent" do
    lazy_eval(lambda { parent }).should be_nil
  end

  it "should not resolve #index" do
    lambda { lazy_eval(lambda { index }) }.should raise_error(NoMethodError)
  end
end

describe BinData::LazyEvaluator, "with one parent" do
  subject {
    parent_methods = {:m1 => 'Pm1', :com => 'PmC', :mm => 3}
    parent_params  = {:p1 => 'Pp1', :com => 'PpC'}
    parent_obj = MockBinDataObject.new(parent_methods, parent_params)

    def parent_obj.echo(a1, a2)
      [a1, a2]
    end

    methods = {:m1 => 'm1', :com => 'mC'}
    params  = {:p1 => 'p1', :com => 'pC'}
    MockBinDataObject.new(methods, params, parent_obj)
  }

  it "should evaluate raw value" do
    lazy_eval(5).should == 5
  end

  it "should evaluate value" do
    lazy_eval(lambda { 5 }).should == 5
  end

  it "should evaluate overrides before params" do
    lazy_eval(lambda { p1 }, :p1 => 'o1').should == 'o1'
  end

  it "should evaluate overrides before methods" do
    lazy_eval(lambda { m1 }, :m1 => 'o1').should == 'o1'
  end

  it "should not resolve any unknown methods" do
    lambda { lazy_eval(lambda { unknown }) }.should raise_error(NameError)
  end

  it "should resolve parameters in the parent" do
    lazy_eval(lambda { p1 }).should == 'Pp1'
  end

  it "should resolve methods in the parent" do
    lazy_eval(lambda { m1 }).should == 'Pm1'
  end

  it "should invoke methods in the parent" do
    lazy_eval(lambda { echo(p1, m1) }).should == ['Pp1', 'Pm1']
  end

  it "should resolve parameters in preference to methods in the parent" do
    lazy_eval(lambda { com }).should == 'PpC'
  end

  it "should have a parent" do
    lazy_eval(lambda { parent }).should_not be_nil
  end

  it "should not resolve #index" do
    lambda { lazy_eval(lambda { index }) }.should raise_error(NoMethodError)
  end
end

describe BinData::LazyEvaluator, "with nested parents" do
  subject {
    pparent_methods = {:m1 => 'PPm1', :m2 => 'PPm2', :com => 'PPmC'}
    pparent_params  = {:p1 => 'PPp1', :p2 => 'PPp2', :com => 'PPpC'}
    pparent_obj = MockBinDataObject.new(pparent_methods, pparent_params)

    def pparent_obj.echo(arg)
      ["PP", arg]
    end

    def pparent_obj.echo2(arg)
      ["PP2", arg]
    end

    parent_methods = {:m1 => 'Pm1', :com => 'PmC', :sym1 => :m2, :sym2 => lambda { m2 }}
    parent_params  = {:p1 => 'Pp1', :com => 'PpC'}
    parent_obj = MockBinDataObject.new(parent_methods, parent_params, pparent_obj)

    def parent_obj.echo(arg)
      ["P", arg]
    end

    methods = {:m1 => 'm1', :com => 'mC'}
    params  = {:p1 => 'p1', :com => 'pC'}
    MockBinDataObject.new(methods, params, parent_obj)
  }

  it "should accept symbols as a shortcut to lambdas" do
    lazy_eval(:p1).should == 'Pp1'
    lazy_eval(:p2).should == 'PPp2'
    lazy_eval(:m1).should == 'Pm1'
    lazy_eval(:m2).should == 'PPm2'
  end

  it "should not resolve any unknown methods" do
    lambda { lazy_eval(lambda { unknown }) }.should raise_error(NameError)
  end

  it "should resolve parameters in the parent" do
    lazy_eval(lambda { p1 }).should == 'Pp1'
  end

  it "should resolve methods in the parent" do
    lazy_eval(lambda { m1 }).should == 'Pm1'
  end

  it "should resolve parameters in the parent's parent" do
    lazy_eval(lambda { p2 }).should == 'PPp2'
  end

  it "should resolve methods in the parent's parent" do
    lazy_eval(lambda { m2 }).should == 'PPm2'
  end

  it "should invoke methods in the parent" do
    lazy_eval(lambda { echo(m1) }).should == ['P', 'Pm1']
  end

  it "should invoke methods in the parent's parent" do
    lazy_eval(lambda { parent.echo(m1) }, { :m1 => 'o1'}).should == ['PP', 'o1']
  end

  it "should invoke methods in the parent's parent" do
    lazy_eval(lambda { echo2(m1) }).should == ['PP2', 'Pm1']
  end

  it "should resolve parameters in preference to methods in the parent" do
    lazy_eval(lambda { com }).should == 'PpC'
  end

  it "should resolve methods in the parent explicitly" do
    lazy_eval(lambda { parent.m1 }).should == 'PPm1'
  end

  it "should cascade lambdas " do
    lazy_eval(lambda { sym1 }).should == 'PPm2'
    lazy_eval(lambda { sym2 }).should == 'PPm2'
  end

  it "should not resolve #index" do
    lambda { lazy_eval(lambda { index }) }.should raise_error(NoMethodError)
  end
end
