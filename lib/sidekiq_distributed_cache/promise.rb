module SidekiqDistributedCache
  class Promise
    attr_accessor :klass, :object_param, :method, :expires_in, :args, :instance_id
    delegate :redis, :log, to: SidekiqDistributedCache

    def initialize(klass: nil, object: nil, method:, expires_in: 1.hour, args: nil, instance_id: nil, cache_tag: nil)
      if object
        @klass = object.class.name
        @object_param = object.to_param
      elsif klass
        @klass = klass
      else
        raise "Must provide either klass or object"
      end
      raise "Must provide method" unless method
      @method = method
      @expires_in = expires_in.to_i
      @args = args
      @instance_id = instance_id
      @cache_tag = cache_tag
    end

    def cache_tag
      @cache_tag ||= begin
        [
          SidekiqDistributedCache.cache_prefix,
          klass,
          (object_param || '.'),
          method,
          (Digest::MD5.hexdigest(args.compact.to_json) if args.present?)
        ].compact * '/'
      end
    end

    def job_interlock_key
      cache_tag + '/in-progress'
    end

    def should_enqueue_job?
      redis.setnx(job_interlock_key, 'winner!') && redis.expire(job_interlock_key, expires_in)
    end

    def enqueue_job!
      SidekiqDistributedCache::Worker.perform_async(klass, object_param, method, args, cache_tag, expires_in, job_interlock_key)
    end

    def execute_and_wait!(timeout)
      execute_and_wait(timeout, raise_on_timeout: true)
    end

    def execute_and_wait(timeout, raise_on_timeout: false)
      found_message = redis.get(cache_tag)
      if found_message
        # found a previously fresh message
        return found_message
      else
        # Start a job if no other client has
        if should_enqueue_job?
          log('promise enqueuing calculator job')
          enqueue_job!
        else
          log('promise calculator job already working')
        end

        # either a job was already running or we started one, now wait for an answer
        if redis.wait_for_done_message(cache_tag, timeout.to_i)
          # ready now, fetch it
          log('promise calculator job finished')
          existing_value
        elsif raise_on_timeout
          log('promise timed out awaiting calculator job')
          raise SidekiqDistributedCache::TimeoutError
        end
      end
    end
  end
end
