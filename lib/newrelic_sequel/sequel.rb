require 'new_relic/agent/method_tracer'

DependencyDetection.defer do
  depends_on do
    defined?(::Sequel)
  end

  depends_on do
    begin
      (Sequel::MAJOR == 3 && Sequel::MINOR >= 22)
    rescue Exception => e
      false
    end
  end

  executes do
    ::Sequel::Model::ClassMethods.class_eval do

      add_method_tracer :[], 'ActiveRecord/#{self.name}/find'

      add_method_tracer :all, 'ActiveRecord/#{self.name}/find'
      add_method_tracer :each, 'ActiveRecord/#{self.name}/find'
      add_method_tracer :create, 'ActiveRecord/#{self.name}/create'
      add_method_tracer :insert, 'ActiveRecord/#{self.name}/create'
      add_method_tracer :insert_multiple, 'ActiveRecord/#{self.name}/create'
      add_method_tracer :import, 'ActiveRecord/#{self.name}/create'
      add_method_tracer :update, 'ActiveRecord/#{self.name}/update'
      add_method_tracer :delete, 'ActiveRecord/#{self.name}/delete'

    end

    ::Sequel::Model::InstanceMethods.class_eval do

      add_method_tracer :_insert, 'ActiveRecord/#{self.class.name[/[^:]*$/]}/create'
      add_method_tracer :_update, 'ActiveRecord/#{self.class.name[/[^:]*$/]}/update'
      add_method_tracer :_delete, 'ActiveRecord/#{self.class.name[/[^:]*$/]}/destroy'

    end

    ::Sequel::Dataset.class_eval do

      add_method_tracer :first, 'ActiveRecord/#{self.respond_to?(:model) ? self.model.name : "Dataset"}/first'
      add_method_tracer :find_all, 'ActiveRecord/#{self.respond_to?(:model) ? self.model.name : "Dataset"}/find_all'
      add_method_tracer :execute, 'ActiveRecord/#{self.respond_to?(:model) ? self.model.name : "Dataset"}/find'
      add_method_tracer :execute_insert, 'ActiveRecord/#{self.respond_to?(:model) ? self.model.name : "Dataset"}/create'
      add_method_tracer :execute_dui, 'ActiveRecord/#{self.respond_to?(:model) ? self.model.name : "Dataset"}/update'
      add_method_tracer :execute_ddl, 'ActiveRecord/#{self.respond_to?(:model) ? self.model.name : "Dataset"}/all'

    end

    ::Sequel::Database.class_eval do

      add_method_tracer :execute, 'ActiveRecord/Database/find'
      add_method_tracer :execute_insert, 'ActiveRecord/Database/create'
      add_method_tracer :execute_dui, 'ActiveRecord/Database/update'
      add_method_tracer :execute_ddl, 'ActiveRecord/Database/all'

    end

  end
end


module NewRelic
  module Agent
    module Instrumentation
      module SequelDurationRecorder
        def self.record(duration, sql)
          return unless NewRelic::Agent.is_execution_traced?
          return unless operation = extract_operation_from_sql(sql)

          NewRelic::Agent.instance.transaction_sampler.notice_sql(sql, nil, duration)

          metrics = ["ActiveRecord/#{operation}", 'ActiveRecord/all']
          metrics.each do |metric|
            NewRelic::Agent.instance.stats_engine.get_stats_no_scope(metric).trace_call(duration)
          end
        end

        def self.extract_operation_from_sql(sql)
          case sql[0...15]
          when /^\s*select/i then
            'find'
          when /^\s*(update|insert)/i then
            'save'
          when /^\s*delete/i then
            'destroy'
          when /^\s*with (?:recursive)?/i then
            # Recursive queries for Postgresql
            # Syntax is: WITH [RECURSIVE]
            # The results can be used to select/update/delete rows
            # we're always tracking it as select here, because finding what the
            # "real" action is, probably require a full SQL parser.
            'find'
          else
            nil
          end
        end
      end

      module SequelInstrumentation
        def self.included(klass)
          klass.class_eval do
            alias_method :log_duration_without_newrelic_instrumentation, :log_duration
            alias_method :log_duration, :log_duration_with_newrelic_instrumentation
          end
        end

        def log_duration_with_newrelic_instrumentation(duration, sql)
          SequelDurationRecorder.record(duration, sql)
        ensure
          log_duration_without_newrelic_instrumentation(duration, sql)
        end
      end
    end
  end
end

DependencyDetection.defer do
  depends_on do
    defined?(::Sequel) && defined?(::Sequel::Database)
  end

  executes do
    if defined?(SequelRails)
      NewRelic::Agent.logger.info 'Installing Sequel instrumentation (via sequel-rails)'
      ActiveSupport::Notifications.subscribe("sql.sequel") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        duration = (event.end - event.time).to_f
        ::NewRelic::Agent::Instrumentation::SequelDurationRecorder.record(duration, event.payload[:sql])
      end
    else
      NewRelic::Agent.logger.info 'Installing Sequel instrumentation'
      ::Sequel::Database.class_eval do
        include ::NewRelic::Agent::Instrumentation::SequelInstrumentation
      end
    end
  end
end
