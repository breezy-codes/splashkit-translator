require_relative 'abstract_translator'

module Translators
  #
  # Website docs generator
  #
  class Docs < AbstractTranslator
    def initialize(data, logging = false)
      super(data, logging)
    end

    def render_templates
      data = grouped_data
      {
        'api.json' => JSON.pretty_generate(data)
      }
    end

    def grouped_data
      @data
        .group_by { |_, header| header[:group] }
        .map do |group_key, group_data|
          group_template = {
            brief: '',
            description: '',
            functions: [],
            typedefs: [],
            structs: [],
            enums: [],
            defines: []
          }
          group_data =
            group_data.to_h.values.reduce(group_template) do |memo, header_data|
              header_data.each do |key, value|
                next if value.nil? || !memo.key?(key)
                memo[key] += value unless value.empty?
              end
              memo
            end
          map_signatures(group_data)
          [group_key, group_data]
        end.sort.to_h
    end

    def run_for_each_adapter
      # Must translate in order of adapters (case conversion must be
      # in order as String is prepended)
      Translators.adapters.each do |adpt|
        adpt = adpt.new(@data)
        yield adpt
      end
    end

    def map_signatures(data)
      run_for_each_adapter do |adpt|
        # Map function signatures
        data[:functions].each do |function_data|
          function_data[:signatures] ||= {}
          signature = adpt.respond_to?(:docs_signatures_for) ?
                      adpt.docs_signatures_for(function_data) :
                      adpt.sk_signature_for(function_data)
          function_data[:signatures][adpt.name] = signature
        end
    
        # Map enum signatures
        # ============================================================================================
        # This is the new code that maps the enum signatures, it accounts for the new enum_signature_syntax
        data[:enums].each do |enum_data|
          enum_data[:signatures] ||= {}
          enum_values = enum_data[:constants].map do |const_name, const_details|
            { name: const_name, description: const_details[:description], value: const_details[:number] }
          end

          if adpt.respond_to?(:enum_signature_syntax)
            enum_signature = adpt.enum_signature_syntax(enum_data[:name], enum_values)
            enum_data[:signatures][adpt.name] = enum_signature
          end
        end
      end
    end

    def post_execute
      puts 'Place `api.json` in the `data` directory of the `splashkit.io` repo'
    end
  end
end
