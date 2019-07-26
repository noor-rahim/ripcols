require "json"
require "ripcols/ripper"
require "ripcols/version"

module Ripcols
  at_exit {
    # req_file = self.caller_files.first
    patterns = Object.constants
      .filter { |c| c.to_s.start_with?("HEADER_") || c.to_s.start_with?("LINE_") }
      .map { |c| [c, Object.const_get(c)] }
      .to_h
   
    f =  open( ::ARGV.first )
    p JSON.dump(Ripper.new( patterns, f ).parse)
    
  }

  private
 
  # taken from 
  # https://github.com/sinatra/sinatra/blob/eee711bce740d38a9a91aa6028688c9a6d74b23b/lib/sinatra/base.rb#L1505


  # Like Kernel#caller but excluding certain magic entries and without
  # line / method information; the resulting array contains filenames only.
  def self.caller_files
    cleaned_caller(1).flatten
  end


  CALLERS_TO_IGNORE = [ # :nodoc:
    /^\(.*\)$/,                                         # generated code
    /rubygems\/(custom|core_ext\/kernel)_require\.rb$/, # rubygems require hacks
    /bundler(\/(?:runtime|inline))?\.rb/,               # bundler require hacks
    /<internal:/,                                       # internal in ruby >= 1.9.2
    /src\/kernel\/bootstrap\/[A-Z]/                     # maglev kernel files
  ]

  # Like Kernel#caller but excluding certain magic entries
  def self.cleaned_caller(keep = 3)
    Kernel.caller(1).
      map!    { |line| line.split(/:(?=\d|in )/, 3)[0,keep] }.
      reject { |file, *_| CALLERS_TO_IGNORE.any? { |pattern| file =~ pattern } }
  end

end
