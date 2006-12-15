require 'mem_inspect'

##
# An abstract viewer class
#
# Use the PNGViewer as an example.

class MemInspect::Viewer

  ##
  # Intializes the visualization.

  def initialize(width, height)
    @width = width
    @height = height
    @max = @width * @height

    @mem_inspect = MemInspect.new
  end

  ##
  # Returns x, y coordinates for +address+ based on the width and height of
  # the visualization.

  def coords_for(address)
    index = address / 20

    if index > @max then
      raise "Ran out of plot space at index %d for 0x%x" % [index, address]
    end

    x = index % @width
    y = index / @width

    return x, y
  end

end

