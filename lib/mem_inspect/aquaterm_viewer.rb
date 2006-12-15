require 'osx/cocoa'
require 'mem_inspect'
require 'mem_inspect/viewer'

##
# Prints plots of memory to an AquaTerm window.
#
# Requires RubyCocoa and the AquaTerm framework.

class MemInspect::AquatermViewer < MemInspect::Viewer
  OSX::NSBundle.bundleWithPath(File.expand_path("/Library/Frameworks/Aquaterm.framework")).load
  OSX.ns_import :AQTAdapter

  BLACK = 0 # unalloc
  WHITE = 1
  RED = 2
  GREEN = 3
  GRAY = 4 # free

  ##
  # Creates a new AquatermViewer.

  def initialize(width, height)
    super

    @adapter = OSX::AQTAdapter.alloc.init
    @adapter.openPlotWithIndex 1
    @adapter.setPlotSize [@width, @height]
    @adapter.setPlotTitle 'Memory Map'

    @adapter.setColormapEntry_red_green_blue 0, 0.0, 0.0, 0.0 # black
    @adapter.setColormapEntry_red_green_blue 1, 1.0, 1.0, 1.0 # white
    @adapter.setColormapEntry_red_green_blue 2, 1.0, 0.0, 0.0 # red
    @adapter.setColormapEntry_red_green_blue 3, 0.0, 1.0, 0.0 # green
    @adapter.setColormapEntry_red_green_blue 4, 0.7, 0.7, 0.7 # gray
  end

  ##
  # Draws a plot and renders it in the active plot window.

  def draw
    fill_background
    color = BLACK
    last_color = color
    x = 0
    y = 0

    @mem_inspect.walk do |address, size, object|
      x, y = coords_for address

      color = case object
              when :__free then GRAY
              when :__node then RED
              when :__varmap, :__scope, :__unknown then WHITE
              else GREEN
              end

      @adapter.takeColorFromColormapEntry color unless color == last_color
      @adapter.moveToPoint [x, y] if x == 0
      @adapter.addLineToPoint [x + 1, y + 1]
      last_color = color
    end

  ensure # coords_for raises when out-of-bounds
    @adapter.renderPlot
  end

  ##
  # Fills the background of the plot, erasing the current contents.

  def fill_background
    @adapter.takeColorFromColormapEntry BLACK
    @adapter.addFilledRect [0, 0, @width, @height] # background
  end

  ##
  # Close the plot

  def close
    @adapter.closePlot
  end

end

