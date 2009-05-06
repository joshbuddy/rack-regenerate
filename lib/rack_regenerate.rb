require 'thread'
require 'rack'
require 'net/http'
require 'uri'

module Rack
  class Regenerate
    
    def initialize(app)
      @app = app
      @schedule_mutex = Mutex.new
      @schedule = Tree.new
      
      @fetch_queue = Queue.new
      
      @fetcher = Thread.new do
        while true
          begin 
            url = URI.parse(@fetch_queue.pop)
            Net::HTTP.new(url.host, url.port).start {|http| http.get(url.request_uri, {'X-Cache-Regenerate' => 'Supress'}) }
          rescue Exception => e
            puts "e: #{e}"
          end
        end
      end

      @scheduler = Thread.new do
        while true
          begin
            start_time = Time.now.to_f
            current_id = Time.now.to_i
            @schedule_mutex.synchronize do
              if jobs = @schedule.next(current_id)
                job_url_hash = jobs.inject({}) { |h, job| h[job.url] = job unless h[job.url]; h }
                job_url_hash.each do |url, job|
                  if new_job = job.decr
                    @fetch_queue << job.url
                    @schedule.add(current_id + new_job.interval, new_job)
                  end
                end
              end
            end
            sleep(start_time - Time.now.to_f + 1)
          rescue Exception => e
            puts "e: #{e}"
            sleep(1)
          end
        end
      end
      
    end
    
    def call(env)
      response = @app.call(env)
      if response && (cache_regenerate = response[1]['X-Cache-Regenerate']) && env['HTTP_X_CACHE_REGENERATE'] != 'Supress'
        timing = cache_regenerate.split(' ').map{|part| part.to_i}
        @schedule_mutex.synchronize { @schedule.add(Time.now.to_i + timing.first, Job.new(Rack::Request.new(env).url, timing.first, timing.last)) }
      end
      response[1].delete('X-Cache-Regenerate')
      response
    end
    
    class Job
      
      attr_reader :url, :interval, :count
      
      def initialize(url, interval, count)
        @url = url
        @interval = interval
        @count = count
      end
      
      def decr
        case count
        when -1
          Job.new(url, interval, count)
        when 0
          nil
        else
          Job.new(url, interval, count - 1)
        end
      end
      
    end
    
    class Tree

      attr_reader :root
      
      def initialize
        @root = Node.new(0, nil)
        @position = @root
      end
      
      def add(id, value)
        target = @root
        until target.values.last.equal?(value)
          if target.id == id
            target.values << value
          elsif id < target.id
            if target.lvalue
              target = target.lvalue
            else
              target.lvalue = Node.new(id, value)
              target.lvalue.parent = target
              target = target.lvalue
              return
            end
          else
            if target.rvalue
              target = target.rvalue
            else
              target.rvalue = Node.new(id, value)
              target.rvalue.parent = target
              target = target.rvalue
              return
            end
          end
        end
        
      end
      
      def reset!
        @position = @root
      end
      
      def next(id)
        pos = next_node(@position, id)
        if pos && pos.id == id
          pos.values
        else
          nil
        end
      end
      
      def next_node(node, id)
        if node.id == id
          if node.lvalue.nil? && node.rvalue.nil?
            if node.parent.lvalue == node
              node.parent.lvalue = nil
            else
              node.parent.rvalue = nil
            end
          end
          node
        elsif id < node.id && node.lvalue
          next_node(node.lvalue, id)
        elsif id > node.id && node.rvalue
          next_node(node.rvalue, id)
        end
      end

      class Node
        attr_accessor :lvalue, :rvalue, :values, :id, :parent
        
        def initialize(id, value)
          @id = id
          @values = Array(value)
        end
      end
      
    end
    
    
  end
end