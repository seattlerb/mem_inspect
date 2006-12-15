require 'rubygems'
require 'rake'

$VERBOSE = nil

$spec = Gem::Specification.new do |s|
  s.name = 'mem_inspect'
  s.version = '1.0.0'
  s.summary = 'ObjectSpace.each_object on crack'
  s.description = 'mem_inspect walks Ruby\'s heaps giving you the contents of
each slot.  mem_inspect also includes viewers that will let you visualize
the contents of Ruby\'s heap.'
  s.author = 'Eric Hodel'
  s.email = 'drbrain@segment7.net'

  s.has_rdoc = true
  s.files = File.read('Manifest.txt').split($/)
  s.require_path = 'lib'

  s.executables = %w[ruby_mem_dump ruby_mem_inspect_build]

  s.add_dependency 'RubyInline', '>= 3.5.0'
  s.add_dependency 'png', '>= 1.0.0'
end

require '../../tasks/project_defaults'

# vim: syntax=Ruby

