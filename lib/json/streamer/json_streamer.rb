require "json/stream"

module Json
  module Streamer
    class JsonStreamer

      attr_reader :aggregator
      attr_reader :parser

      def initialize(file_io = nil, chunk_size = 1000)
        @parser = JSON::Stream::Parser.new

        @file_io = file_io
        @chunk_size = chunk_size

        @current_level = -1
        @aggregator = []
        @aggregator_keys = {}

        @parser.start_object {start_object}
        @parser.start_array {start_array}
        @parser.key {|k| key(k)}
      end

      def <<(data)
        @parser << data
      end

      # Callbacks containing `yield` have to be defined in the method called via block otherwise yield won't work
      def get(nesting_level: -1, key: nil, yield_values: true, symbolize_keys: false)
        @yield_level = nesting_level
        @yield_key = key
        @yield_values = yield_values
        @symbolize_keys = symbolize_keys

        @parser.value do |v|
          value(v) { |desired_object| yield desired_object }
        end

        @parser.end_object do
          end_level { |desired_object| yield desired_object }
        end

        @parser.end_array do
          end_level { |desired_object| yield desired_object }
        end

        @file_io.each(@chunk_size) { |chunk| @parser << chunk } if @file_io
      end

      def start_object
        new_level(Hash.new)
      end

      def start_array
        new_level(Array.new)
      end

      def key(k)
        set_aggregator_key(@symbolize_keys ? k.to_sym : k)
      end

      def current_key
        @aggregator_keys[@current_level]
      end

      def value(value)
        yield value if yield_value?
        add_value(value)
      end

      def add_value(value)
        if array_level?(@current_level)
          @aggregator.last[:data] << value
        else
          @aggregator.last[:data][current_key] = value
        end
      end

      def end_level
        if yield_object?
          yield @aggregator.last[:data].clone
        else
          merge_up
        end

        @aggregator.pop
        remove_aggregator_key
        @current_level -= 1
      end

      def yield_object?
        @current_level.eql?(@yield_level) or (not @yield_key.nil? and @yield_key == previous_key)
      end

      def yield_value?
        @yield_values and ((next_level).eql?(@yield_level) or (not @yield_key.nil? and @yield_key == current_key))
      end

      def new_level(type)
        @current_level += 1
        @aggregator.push(data: type)
      end

      def set_aggregator_key(key)
        @aggregator_keys[@current_level] = key
      end

      def remove_aggregator_key
        @aggregator_keys.tap { |h| h.delete(@current_level.to_s) }
      end

      def array_level?(nesting_level)
        @aggregator[nesting_level][:data].is_a?(Array)
      end

      def merge_up
        return if @current_level.zero?

        if array_level?(previous_level)
          @aggregator[previous_level][:data] << @aggregator.last[:data]
        else
          @aggregator[previous_level][:data][previous_key] = @aggregator.last[:data]
        end
      end

      def previous_level
        @current_level - 1
      end

      def next_level
        @current_level + 1
      end

      def previous_key
        @aggregator_keys[previous_level]
      end
    end
  end
end
