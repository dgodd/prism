# A params validation module.
#
# Implemented inline validations (defined as `:validate` option on param):
# - *size* (`Range | Int32`) - Validate size;
# - *min* (`Comparable`) - Check if param value `>=` than min;
# - *max* (`Comparable`) - Check if param value `<=` than max;
# - *min!* (`Comparable`) - Check if param value `>` than min;
# - *max!* (`Comparable`) - Check if param value `<` than max;
# - *in* (`Enumerable`) - Validate if param value is included in range or array etc.;
# - *regex* (`Regex`) - Validate if param value matches regex;
# - *custom* (`Proc`) - Custom validation, see example below;
#
# ```
# class SimpleAction
#   include Prism::Params
#
#   params do
#     param :name, String, validate: {
#       size:   (3..32),
#       regex:  /\w+/,
#       custom: ->(name : String) {
#         error!(:name, "doesn't meet condition") unless some_condition?(name)
#       },
#     }
#     param :age, Int32?, validate: {in: (18..150)}
#   end
#
#   def self.call(context)
#     params = parse_params(context)
#   end
# end
# ```
#
# NOTE: A `#nil?` validation will be run at first if the param is defined as non-nilable.
module Prism::Params::Validation
  private macro validate_param(param, value)
    {% if validations = param[:validate] %}
      unless {{value}}.nil?
        value = {{value}}.not_nil!

        {%
          name = if param[:parents]
                   if param[:parents].size == 1
                     "#{param[:parents].first}[#{param[:name]}]"
                   elsif param[:parents].size > 1
                     "#{param[:parents].first}[#{(param[:parents][1..-1] + [param[:name]]).join("][")}]"
                   end
                 else
                   param[:name]
                 end
        %}

        {% if validations[:size] %}
          case size = {{validations[:size].id}}
          when Int32
            unless value.size == size
              error!({{name}}, "must have exact size of #{size}")
            end
          when Range
            unless (size).includes?(value.size)
              error!({{name}}, "must have size in range of #{size}")
            end
          end
        {% end %}

        {% if validations[:in] %}
          unless ({{validations[:in]}}).includes?(value)
            error!({{name}}, "must be included in {{validations[:in].id}}")
          end
        {% end %}

        {% if validations[:min] %}
          unless value >= {{validations[:min]}}
            error!({{name}}, "must be greater or equal to {{validations[:min].id}}")
          end
        {% end %}

        {% if validations[:max] %}
          unless value <= {{validations[:max]}}
            error!({{name}}, "must be less or equal to {{validations[:max].id}}")
          end
        {% end %}

        {% if validations[:min!] %}
          unless value > {{validations[:min!]}}
            error!({{name}}, "must be greater than {{validations[:min!].id}}")
          end
        {% end %}

        {% if validations[:max!] %}
          unless value < {{validations[:max!]}}
            error!({{name}}, "must be less than {{validations[:max!].id}}")
          end
        {% end %}

        {% if validations[:regex] %}
          unless {{validations[:regex]}}.match(value)
            error!({{name}}, "must match {{validations[:regex].id}}")
          end
        {% end %}

        {% if validations[:custom] %}
          {{validations[:custom].id}}.call(value)
        {% end %}
      end
    {% end %}
  end

  # Raise `InvalidParamError` for param *name* with *description*.
  macro error!(name, description)
    raise InvalidParamError.new({{name.id.stringify}}, {{description}})
  end
end
