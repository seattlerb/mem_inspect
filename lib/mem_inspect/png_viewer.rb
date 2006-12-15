begin
  require 'png'
rescue LoadError
  require 'rubygems'
  require 'png'
end
require 'mem_inspect'
require 'mem_inspect/viewer'

##
# Prints plots of memory as a PNG.

class MemInspect::PNGViewer < MemInspect::Viewer

  ##
  # Draws a PNG and saves it to memory_map.PID.timestamp.png

  def draw
    canvas = PNG::Canvas.new @width, @height, PNG::Color::Black
    x = 0
    y = 0
    color = nil

    @mem_inspect.walk do |address, size, object|
      x, y = coords_for address

      color = case object
              when :__free    then PNG::Color::Gray
              when :__node    then PNG::Color::Red
              when :__scope   then PNG::Color::Yellow
              when :__varmap  then PNG::Color::Purple
              when :__unknown then PNG::Color::Orange
              when :__iclass  then PNG::Color::White
              else                 PNG::Color::Green
              end

      canvas[x, y] = color
    end

  ensure # coords_for raises when out-of-bounds
    png = PNG.new canvas
    file = "memory_map.#{$$}.#{Time.now.to_i}.png"
    png.save file
  end

end

