# frozen_string_literal: true

RgGen.define_simple_feature(:bit_field, :sv_rtl_top) do
  sv_rtl do
    include RgGen::SystemVerilog::RTL::BitFieldIndex

    export :value

    build do
      if fixed_initial_value?
        localparam :initial_value, {
          name: initial_value_name, data_type: :bit, width: bit_field.width,
          array_size: initial_value_size, array_format: initial_value_format,
          default: initial_value_lhs
        }
      elsif initial_value?
        parameter :initial_value, {
          name: initial_value_name, data_type: :bit, width: bit_field.width,
          array_size: initial_value_size, array_format: initial_value_format,
          default: initial_value_lhs
        }
      end
      interface :bit_field_sub_if, {
        name: 'bit_field_sub_if',
        interface_type: 'rggen_bit_field_if',
        parameter_values: [bit_field.width]
      }
    end

    main_code :register do
      local_scope("g_#{bit_field.name}") do |scope|
        scope.loop_size loop_size
        scope.parameters parameters
        scope.variables variables
        scope.body(&method(:body_code))
      end
    end

    pre_code :bit_field do |code|
      code << bit_field_if_connection << nl
    end

    def value(offsets = nil, width = nil)
      value_lsb = bit_field.lsb(offsets&.last || local_index)
      value_width = width || bit_field.width
      register_if(offsets&.slice(0..-2)).value[value_lsb, value_width]
    end

    private

    [:fixed_initial_value?, :initial_value_array?, :initial_value?].each do |m|
      define_method(m) { bit_field.__send__(__method__) }
    end

    def register_if(offsets)
      index = register.index(offsets || register.local_indices)
      register_block.register_if[index]
    end

    def initial_value_name
      identifiers = []
      identifiers << bit_field.full_name('_') unless fixed_initial_value?
      identifiers << 'initial_value'
      identifiers.join('_').upcase
    end

    def initial_value_size
      initial_value_array? && [bit_field.sequence_size] || nil
    end

    def initial_value_format
      fixed_initial_value? && :unpacked ||
        configuration.array_port_format
    end

    def initial_value_lhs
      initial_value_array? && initial_value_array_lhs || sized_initial_value
    end

    def initial_value_array_lhs
      if fixed_initial_value?
        array(sized_initial_values)
      elsif initial_value_format == :unpacked
        array(default: sized_initial_value)
      else
        repeat(bit_field.sequence_size, sized_initial_value)
      end
    end

    def sized_initial_value
      bit_field.initial_value &&
        hex(bit_field.initial_value, bit_field.width)
    end

    def sized_initial_values
      bit_field.initial_values&.map { |v| hex(v, bit_field.width) }
    end

    def loop_size
      loop_variable = local_index
      loop_variable &&
        { loop_variable => bit_field.sequence_size }
    end

    def parameters
      bit_field.declarations[:parameter]
    end

    def variables
      bit_field.declarations[:variable]
    end

    def body_code(code)
      bit_field.generate_code(code, :bit_field, :top_down)
    end

    def bit_field_if_connection
      macro_call(
        :rggen_connect_bit_field_if,
        [
          register.bit_field_if,
          bit_field.bit_field_sub_if,
          bit_field.lsb(local_index),
          bit_field.width
        ]
      )
    end
  end
end
