require 'sass'
require 'sass/util'
require 'sass/script'

module Sass::Script::Functions
  def colors(color)
    color = color.to_s.gsub('"','')       
    v = ENV["#{color.underscore.upcase}_COLOR"] || DEFAULT_COLORS[color]
    Sass::Script::Value::Color.from_hex(v)
  end 
end