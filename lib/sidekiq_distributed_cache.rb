require "sidekiq_distributed_cache/worker"
require "sidekiq_distributed_cache/promise"
require "sidekiq_distributed_cache/redis"

module SidekiqDistributedCache
  class TimeoutError < StandardError; end

  class << self
    attr_accessor :cache_prefix, :redis_pool, :logger, :log_level
  end

  def self.log(message)
    logger.send((log_level || :info), message) if logger
  end

  def self.redis
    @redis ||= Redis.new(redis_pool)
  end
end
