require 'bindata/base'
require 'bindata/dsl'

module BinData
  # An Array is a list of data objects of the same type.
  #
  #   require 'bindata'
  #
  #   data = "\x03\x04\x05\x06\x07\x08\x09"
  #
  #   obj = BinData::Array.new(:type => :int8, :initial_length => 6)
  #   obj.read(data) #=> [3, 4, 5, 6, 7, 8]
  #
  #   obj = BinData::Array.new(:type => :int8,
  #                            :read_until => lambda { index == 1 })
  #   obj.read(data) #=> [3, 4]
  #
  #   obj = BinData::Array.new(:type => :int8,
  #                            :read_until => lambda { element >= 6 })
  #   obj.read(data) #=> [3, 4, 5, 6]
  #
  #   obj = BinData::Array.new(:type => :int8,
  #           :read_until => lambda { array[index] + array[index - 1] == 13 })
  #   obj.read(data) #=> [3, 4, 5, 6, 7]
  #
  #   obj = BinData::Array.new(:type => :int8, :read_until => :eof)
  #   obj.read(data) #=> [3, 4, 5, 6, 7, 8, 9]
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:type</tt>::           The symbol representing the data type of the
  #                            array elements.  If the type is to have params
  #                            passed to it, then it should be provided as
  #                            <tt>[type_symbol, hash_params]</tt>.
  # <tt>:initial_length</tt>:: The initial length of the array.
  # <tt>:read_until</tt>::     While reading, elements are read until this
  #                            condition is true.  This is typically used to
  #                            read an array until a sentinel value is found.
  #                            The variables +index+, +element+ and +array+
  #                            are made available to any lambda assigned to
  #                            this parameter.  If the value of this parameter
  #                            is the symbol :eof, then the array will read
  #                            as much data from the stream as possible.
  #
  # Each data object in an array has the variable +index+ made available
  # to any lambda evaluated as a parameter of that data object.
  class Array < BinData::Base
    include DSLMixin
    include Enumerable

    dsl_parser :array

    mandatory_parameter :type
    optional_parameters :initial_length, :read_until
    mutually_exclusive_parameters :initial_length, :read_until

    class << self

      def sanitize_parameters!(params) #:nodoc:
        unless params.has_parameter?(:initial_length) or
                 params.has_parameter?(:read_until)
          # ensure one of :initial_length and :read_until exists
          params[:initial_length] = 0
        end

        params.warn_replacement_parameter(:read_length, :initial_length)

        params.merge!(dsl_params)

        if params.needs_sanitizing?(:type)
          el_type, el_params = params[:type]
          params[:type] = params.create_sanitized_object_prototype(el_type, el_params)
        end
      end
    end

    def initialize_shared_instance
      @element_prototype = get_parameter(:type)
    end

    def initialize_instance
      @element_list = nil
    end

    def clear?
      @element_list.nil? or elements.all? { |el| el.clear? }
    end

    def clear
      @element_list = nil
    end

    def assign(array)
      raise ArgumentError, "can't set a nil value for #{debug_name}" if array.nil?

      @element_list = to_storage_formats(array.to_ary)
    end

    def snapshot
      elements.collect { |el| el.snapshot }
    end

    def find_index(obj)
      elements.index(obj)
    end
    alias_method :index, :find_index

    # Returns the first index of +obj+ in self.
    #
    # Uses equal? for the comparator.
    def find_index_of(obj)
      elements.index { |el| el.equal?(obj) }
    end

    def push(*args)
      insert(-1, *args)
      self
    end
    alias_method :<<, :push

    def unshift(*args)
      insert(0, *args)
      self
    end

    def concat(array)
      insert(-1, *array.to_ary)
      self
    end

    def insert(index, *objs)
      extend_array(index - 1)
      elements.insert(index, *to_storage_formats(objs))
      self
    end

    # Returns the element at +index+.
    def [](arg1, arg2 = nil)
      if arg1.respond_to?(:to_int) and arg2.nil?
        slice_index(arg1.to_int)
      elsif arg1.respond_to?(:to_int) and arg2.respond_to?(:to_int)
        slice_start_length(arg1.to_int, arg2.to_int)
      elsif arg1.is_a?(Range) and arg2.nil?
        slice_range(arg1)
      else
        raise TypeError, "can't convert #{arg1} into Integer" unless arg1.respond_to?(:to_int)
        raise TypeError, "can't convert #{arg2} into Integer" unless arg2.respond_to?(:to_int)
      end
    end
    alias_method :slice, :[]

    def slice_index(index)
      extend_array(index)
      at(index)
    end

    def slice_start_length(start, length)
      elements[start, length]
    end

    def slice_range(range)
      elements[range]
    end
    private :slice_index, :slice_start_length, :slice_range

    # Returns the element at +index+.  Unlike +slice+, if +index+ is out
    # of range the array will not be automatically extended.
    def at(index)
      elements[index]
    end

    # Sets the element at +index+.
    def []=(index, value)
      extend_array(index)
      elements[index].assign(value)
    end

    # Returns the first element, or the first +n+ elements, of the array.
    # If the array is empty, the first form returns nil, and the second
    # form returns an empty array.
    def first(n = nil)
      if n.nil? and empty?
        # explicitly return nil as arrays grow automatically
        nil
      elsif n.nil?
        self[0]
      else
        self[0, n]
      end
    end

    # Returns the last element, or the last +n+ elements, of the array.
    # If the array is empty, the first form returns nil, and the second
    # form returns an empty array.
    def last(n = nil)
      if n.nil?
        self[-1]
      else
        n = length if n > length
        self[-n, n]
      end
    end

    def length
      elements.length
    end
    alias_method :size, :length

    def empty?
      length.zero?
    end

    # Allow this object to be used in array context.
    def to_ary
      collect { |el| el }
    end

    def each
      elements.each { |el| yield el }
    end

    def debug_name_of(child) #:nodoc:
      index = find_index_of(child)
      "#{debug_name}[#{index}]"
    end

    def offset_of(child) #:nodoc:
      index = find_index_of(child)
      sum = sum_num_bytes_below_index(index)

      child.do_num_bytes.is_a?(Integer) ? sum.ceil : sum.floor
    end

    def do_read(io) #:nodoc:
      if has_parameter?(:initial_length)
        elements.each { |el| el.do_read(io) }
      elsif has_parameter?(:read_until)
        read_until(io)
      end
    end

    def do_write(io) #:nodoc:
      elements.each { |el| el.do_write(io) }
    end

    def do_num_bytes #:nodoc:
      sum_num_bytes_for_all_elements
    end

    #---------------
    private

    def extend_array(max_index)
      max_length = max_index + 1
      while elements.length < max_length
        append_new_element
      end
    end

    def to_storage_formats(els)
      els.collect { |el| new_element(el) }
    end

    def read_until(io)
      if get_parameter(:read_until) == :eof
        read_until_eof(io)
      else
        read_until_condition(io)
      end
    end

    def read_until_eof(io)
      loop do
        element = append_new_element
        begin
          element.do_read(io)
        rescue
          elements.pop
          break
        end
      end
    end

    def read_until_condition(io)
      loop do
        element = append_new_element
        element.do_read(io)
        variables = { :index => self.length - 1, :element => self.last,
                      :array => self }
        break if eval_parameter(:read_until, variables)
      end
    end

    def elements
      if @element_list.nil?
        @element_list = []
        if has_parameter?(:initial_length)
          eval_parameter(:initial_length).times do
            @element_list << new_element
          end
        end
      end
      @element_list
    end

    def append_new_element
      element = new_element
      elements << element
      element
    end

    def new_element(value = nil)
      @element_prototype.instantiate(value, self)
    end

    def sum_num_bytes_for_all_elements
      sum_num_bytes_below_index(length)
    end

    def sum_num_bytes_below_index(index)
      (0...index).inject(0) do |sum, i|
        nbytes = elements[i].do_num_bytes

        if nbytes.is_a?(Integer)
          sum.ceil + nbytes
        else
          sum + nbytes
        end
      end
    end
  end
end
