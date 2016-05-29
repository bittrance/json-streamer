require "json/streamer/version"
require "json/stream"

module Json
  module Streamer
    class JsonStreamer

      attr_reader :aggregator

      def initialize(file_io, chunk_size = 1000)
        @parser = JSON::Stream::Parser.new

        @file_io = file_io
        @chunk_size = chunk_size

        @current_nesting_level = 0
        @current_key = nil
        @aggregator = {}
        @temp_aggregator_keys = {}

        @parser.start_object {start_object}
        @parser.start_array {start_array}
        @parser.key {|k| key(k)}

      end

      def get(nesting_level:-1, key:nil)
        @yield_nesting_level = nesting_level
        @wanted_key = key

        @parser.value do |v|
          if @aggregator[@current_nesting_level].kind_of? Array
            @aggregator[@current_nesting_level] << v
          else
            @aggregator[@current_nesting_level][@current_key] = v
            if yield_value?
              yield v
            end
          end
        end

        # Callback containing yield has be defined in the method called via block
        @parser.end_object do
          if yield_object?
            yield @aggregator[@current_nesting_level].clone
            # TODO probably can be faster than reject!{true}
            @aggregator[@current_nesting_level].reject!{true}
          else
            merge_up
          end

          @current_nesting_level -= 1
        end

        @parser.end_array do
          if yield_object?
            yield @aggregator[@current_nesting_level].clone
            # TODO probably can be faster than reject!{true}
            @aggregator[@current_nesting_level].reject!{true}
          else
            merge_up
          end

          @current_nesting_level -= 1
        end

        @file_io.each(@chunk_size) do |chunk|
          @parser << chunk
        end
      end

      def yield_object?
        @current_nesting_level.eql? @yield_nesting_level or (not @wanted_key.nil? and @wanted_key == @temp_aggregator_keys[@current_nesting_level-1])
      end

      def yield_value?
        @wanted_key == @current_key
      end

      def start_object
        @temp_aggregator_keys[@current_nesting_level] = @current_key
        @current_nesting_level += 1
        @aggregator[@current_nesting_level] = {}
      end

      def start_array
        @temp_aggregator_keys[@current_nesting_level] = @current_key
        @current_nesting_level += 1
        @aggregator[@current_nesting_level] = []
      end

      def key k
        @current_key = k
      end

      def value v

      end

      def merge_up
        return if @current_nesting_level == 1
        previous_nesting_level = @current_nesting_level - 1
        if @aggregator[previous_nesting_level].kind_of? Array
          @aggregator[previous_nesting_level] << @aggregator[@current_nesting_level]
        else
          @aggregator[previous_nesting_level][@temp_aggregator_keys[previous_nesting_level]] = @aggregator[@current_nesting_level]
        end

        @aggregator.delete(@current_nesting_level)
        @aggregator
      end
    end
  end
end
