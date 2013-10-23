# Timeout long-running blocks
#
# == Synopsis
#
#   require 'timeout'
#   status = Timeout::timeout(5) {
#     # Something that should be interrupted if it takes more than 5 seconds...
#   }
#
# == Description
#
# Timeout provides a way to auto-terminate a potentially long-running
# operation if it hasn't finished in a fixed amount of time.
#
# Previous versions didn't use a module for namespacing, however
# #timeout is provided for backwards compatibility.  You
# should prefer Timeout#timeout instead.
#
# == Copyright
#
# Copyright:: (C) 2000  Network Applied Communication Laboratory, Inc.
# Copyright:: (C) 2000  Information-technology Promotion Agency, Japan

module Timeout
  # Raised by Timeout#timeout when the block times out.
  class Error < RuntimeError
  end
  class ExitException < ::Exception # :nodoc:
    attr_reader :klass, :thread

    def initialize(*)
      super
      @thread = Thread.current
      freeze
    end

    def exception(*)
      throw(self, caller) if self.thread == Thread.current
      self
    end
  end

  # :stopdoc:
  THIS_FILE = /\A#{Regexp.quote(__FILE__)}:/o
  CALLER_OFFSET = ((c = caller[0]) && THIS_FILE =~ c) ? 1 : 0
  # :startdoc:

  # Perform an operation in a block, raising an error if it takes longer than
  # +sec+ seconds to complete.
  #
  # +sec+:: Number of seconds to wait for the block to terminate. Any number
  #         may be used, including Floats to specify fractional seconds. A
  #         value of 0 or +nil+ will execute the block without any timeout.
  # +klass+:: Exception Class to raise if the block fails to terminate
  #           in +sec+ seconds.  Omitting will use the default, Timeout::Error
  #
  # Returns the result of the block *if* the block completed before
  # +sec+ seconds, otherwise throws an exception, based on the value of +klass+.
  #
  # Note that this is both a method of module Timeout, so you can <tt>include
  # Timeout</tt> into your classes so they have a #timeout method, as well as
  # a module method, so you can call it directly as Timeout.timeout().
  def timeout(sec, klass = nil)   #:yield: +sec+
    return yield(sec) if sec == nil or sec.zero?
    message = "execution expired"
    e = Error
    bt = catch((klass||ExitException).new) do |exception|
      begin
        x = Thread.current
        y = Thread.start {
          begin
            sleep sec
          rescue => e
            x.raise e
          else
            x.raise exception, message
          end
        }
        return yield(sec)
      rescue (klass||ExitException) => e
        e.backtrace
      ensure
        if y
          y.kill
          y.join # make sure y is dead.
        end
      end
    end
    rej = /\A#{Regexp.quote(__FILE__)}:#{__LINE__-4}\z/o
    bt.reject! {|m| rej =~ m}
    level = -caller(CALLER_OFFSET).size
    while THIS_FILE =~ bt[level]
      bt.delete_at(level)
    end
    raise(e, message, bt)
  end

  module_function :timeout
end

# Identical to:
#
#   Timeout::timeout(n, e, &block).
#
# This method is deprecated and provided only for backwards compatibility.
# You should use Timeout#timeout instead.
def timeout(n, e = nil, &block)
  Timeout::timeout(n, e, &block)
end

# Another name for Timeout::Error, defined for backwards compatibility with
# earlier versions of timeout.rb.
TimeoutError = Timeout::Error
