require "spec"
require "../src/nbt"

module Spec
  # :nodoc:
  struct NBTEqualExpectation
    def initialize(@expected_value : NBT::Tag)
    end

    def self.recursive_equality(expected_tag : NBT::Tag, actual_tag : NBT::Tag) : Bool
      equality = (actual_tag == expected_tag && actual_tag.raw.class == expected_tag.raw.class)
      return false unless equality
      if actual_tag.raw.is_a? Hash
        expected_tag.raw.as(Hash).all? do |k, v|
          recursive_equality expected_tag.raw.as(Hash)[k], v
        end
      elsif actual_tag.raw.is_a? Array(NBT::Tag)
        actual_tag.raw.as(Array(NBT::Tag)).each.with_index.all? do |i, j|
          recursive_equality expected_tag.raw.as(Array(NBT::Tag))[j], i
        end
      else true
      end
    end

    def match(actual_value : NBT::Tag::Type)
      match NBT::Tag.new actual_value
    end

    def match(actual_value : NBT::Tag)
      NBTEqualExpectation.recursive_equality @expected_value, actual_value
    end

    def failure_message(actual_value : NBT::Tag::Type)
      failure_message NBT::Tag.new actual_value
    end

    def failure_message(actual_value : NBT::Tag)
      expected = @expected_value.inspect
      got = actual_value.inspect
      if expected == got
        expected += " : #{@expected_value.raw.class}"
        got += " : #{actual_value.raw.class}"
      end
      "Expected: #{expected}\n     got: #{got}"
    end

    def negative_failure_message(actual_value)
      "Expected: actual_value != #{@expected_value.inspect}\n     got: #{actual_value.inspect}"
    end
  end

  module Expectations
    def nbt_eq(value : NBT::Tag)
      Spec::NBTEqualExpectation.new value
    end
    def nbt_eq(value : NBT::Tag::Type)
      Spec::NBTEqualExpectation.new NBT::Tag.new value
    end
  end
end

{% for bytesize in {8, 16, 32, 64} %}
  {% for sign in { {"U", "u"}, {"", "i"} } %}
    struct {{sign[0].id}}Int{{bytesize}}
      def inspect(io : IO)
        io << to_s << "{{sign[1].id}}{{bytesize}}"
      end
    end
  {% end %}
{% end %}

{% for float_bytesize in {32, 64} %}
  struct Float{{float_bytesize}}
    def inspect(io : IO)
      io << to_s << "f{{float_bytesize}}"
    end
  end
{% end %}

def construct_nbt_tag_recursive(s) : NBT::Tag::Type
  case s
  when NBT::Tag then s.raw
  when Hash then s.map { |k, v| {k, NBT::Tag.new construct_nbt_tag_recursive v} }.to_h
  when Array then s.map { |i| NBT::Tag.new construct_nbt_tag_recursive i }
  else s.as NBT::Tag::Type
  end
end

macro file_nbt_equality(nbt_file, tag)
  File.open "#{__DIR__}/{{nbt_file.id}}" do |%f|
    %nbt = NBT.read(%f)
    %nbt.should nbt_eq(construct_nbt_tag_recursive({{tag}}))
  end
end

describe NBT do
  it "reads arrays" do
    file_nbt_equality("arrays.nbt", {
      "la" => [-2i64, -1i64, 0i64, 1i64, 2i64],
      "ia" => [-2, -1, 0, 1, 2],
      "ba" => [-2i8, -1i8, 0i8, 1i8, 2i8]
    })
  end

  it "handles big example" do
    byte_sequence = Array(Int8).new(1000) { |n| ((n*n*255+n*7)%100).to_i8 }
    file_nbt_equality("big1.nbt", {
      "byteTest" => 127i8,
      "shortTest" => 32767i16,
      "intTest" => 2147483647i32,
      "longTest" => 9223372036854775807i64,
      "floatTest" => 0.49823147f32,
      "doubleTest" => 0.4931287132182315f64,
      "listTest (long)" => [11i64, 12i64, 13i64, 14i64, 15i64],
      "listTest (compound)" => [
        {"name" => "Compound tag #0", "created-on" => 1264099775885i64},
        {"name" => "Compound tag #1", "created-on" => 1264099775885i64}
      ],
      "nested compound test" => {
        "ham" => {"name" => "Hampus", "value" => 0.75f32},
        "egg" => {"name" => "Eggbert", "value" => 0.5f32}
      },
      "byteArrayTest (the first 1000 values of (n*n*255+n*7)%100, starting with n=0 (0, 62, 34, 16, 8, ...))" => byte_sequence,
      "stringTest" => "HELLO WORLD THIS IS A TEST STRING ÅÄÖ!"
    })
  end
end