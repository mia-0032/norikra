require 'mizuno/server'
require 'rack/builder'
require 'msgpack-rpc-over-http'

require_relative 'handler'
require_relative 'gatekeeper'

require 'norikra/logger'
include Norikra::Log

module Norikra::RPC
  class HTTP
    DEFAULT_LISTEN_HOST = '0.0.0.0'
    DEFAULT_LISTEN_PORT = 26571
    # 26571 = 3026 + 3014 + 2968 + 2950 + 2891 + 2896 + 2975 + 2979 + 2872

    DEFAULT_THREADS = 2

    attr_accessor :host, :port, :threads
    attr_accessor :engine, :mizuno, :thread

    def initialize(opts={})
      @engine = opts[:engine]
      @host = opts[:host] || DEFAULT_LISTEN_HOST
      @port = opts[:port] || DEFAULT_LISTEN_PORT
      @threads = opts[:threads] || DEFAULT_THREADS
      @handler = handler = Norikra::RPC::Handler.new(@engine)
      @app = Rack::Builder.new {
        use Norikra::RPC::Gatekeeper
        run MessagePack::RPCOverHTTP::Server.app(handler)
      }
    end

    def start
      info "RPC server #{@host}:#{@port}, #{@threads} threads"
      @thread = Thread.new do
        @mizuno = Mizuno::Server.new
        options = {
          embedded: true, reuse_address: true,
          threads: @threads, min_threads: @threads,
          port: @port, host: @host
        }
        @mizuno.run(@app, options)
      end
    end

    def stop
      @mizuno.stop
      @thread.kill
      @thread.join
    end

    def shut_off(mode)
      @handler.shut_off(mode)
    end
  end
end
