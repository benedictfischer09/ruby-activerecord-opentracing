# frozen_string_literal: true

require "active_record"
require "opentracing"

require "active_record/open_tracing/version"
require "active_record/open_tracing/processor"
require "active_record/open_tracing/sql_sanitizer"

module ActiveRecord
  module OpenTracing
    def self.instrument(tracer: ::OpenTracing.global_tracer, sanitizer: nil)
      sql_sanitizer = sanitizer && SqlSanitizer.build_sanitizer(sanitizer)
      processor = Processor.new(tracer, sanitizer: sql_sanitizer)

      ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        processor.call(*args)
      end

      self
    end
  end
end
