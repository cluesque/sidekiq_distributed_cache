require 'test_helper'

class SidekiqDistributedCache::Test < ActiveSupport::TestCase
  setup do
    require "sidekiq/launcher"
    Sidekiq.redis = { size: 25 }
    Sidekiq.logger = Rails.logger

    @launcher = Sidekiq::Launcher.new(Sidekiq.options.merge(queues: ['default']));0
    @launcher.run
  end

  teardown do
    @launcher.stop
  end

  test 'model method invocation' do
    doohickey = Doohickey.create!(name: 'foo bar')
    assert_equal doohickey.name, 'foo bar'

    promise = SidekiqDistributedCache::Promise.new(object: doohickey, method: :name, expires_in: 1)
    found_name = promise.execute_and_wait!(1)
    assert_equal doohickey.name, found_name
  end

  class CacheExample
    TIMESLICE = 1
    FRESH_FOR = (TIMESLICE * 2).seconds

    attr_accessor :label, :request_start, :request_timeout, :expect_answer, :expect_duration, :answer
    def initialize(label, request_start, request_timeout, expect_answer, expect_duration)
      @label = label
      @request_start = request_start
      @request_timeout = request_timeout
      @expect_answer = expect_answer
      @expect_duration = expect_duration
      start
      self
    end

    def start
      @start_time = Time.now
      @thread = Thread.new do
        Thread.current[:name] = label
        sleep (request_start - 1.0) * TIMESLICE
        promise = SidekiqDistributedCache::Promise.new(klass: Doohickey, method: :do_a_thing, expires_in: FRESH_FOR)
        begin
          @answer = promise.execute_and_wait!(request_timeout)
        rescue SidekiqDistributedCache::TimeoutError
          @timed_out = true
        end
        @end_time = Time.now
      end
    end

    def join
      @thread.join
    end

    attr_accessor :start_time, :end_time
  end

  EXAMPLES = [
    # label, request_start, request_timeout, expect_answer, expect_duration
    ['A', 1, 3, 'narf 1', 3],
    ['B', 2, 3, 'narf 1', 3],
    ['C', 4, 3, 'narf 1', 4],
    ['D', 6, 3, 'narf 2', 8],
    ['E', 11, 1, nil, 12],
    ['F', 12, 3, 'narf 3', 13],
  ]

  test 'concurrent execution examples' do
    Doohickey.delete_all
    examples = EXAMPLES.map do |ex|
      CacheExample.new(*ex)
    end
    examples.each(&:join) # wait for them to finish
    examples.each do |example|
      if example.expect_answer.nil?
        time_tolerance = 1.5 # redis timeout is not so precise
        assert_nil example.answer, "Example #{example.label} expected no answer, got #{example.answer}"
      else
        time_tolerance = 0.5 # actual invocation time more precise
        assert_equal example.answer, example.expect_answer, "Example #{example.label}"
      end
      # assert_equal example.end_time_slice, example.expect_duration
      assert_in_delta example.end_time, example.start_time + example.expect_duration - 1, time_tolerance,
        "Example #{example.label} started #{example.start_time.strftime("%H:%M:%S.%L")} duration #{example.expect_duration} ended #{example.end_time.strftime("%H:%M:%S.%L")}"
    end
  end
end
