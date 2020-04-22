# frozen_string_literal: true

module ActiveRecord
  module OpenTracing
    class SqlSanitizer
      require 'active_record/opentracing/sql_regex'
      include ActiveRecord::OpenTracing::SqlRegex

      attr_accessor :database_engine

      def initialize(raw_sql, database_engine: :mysql)
        @raw_sql = raw_sql
        @database_engine = database_engine
        @sanitized = false # only sanitize once.
      end

      def sql
        @sql ||= scrubbed(@raw_sql.dup) # don't do this in initialize as it is extra work that isn't needed unless we have a slow transaction.
      end

      def to_s
        if @sanitized
          sql
        else
          @sanitized = true
        end
        case database_engine
        when :postgres then to_s_postgres
        when :mysql    then to_s_mysql
        when :sqlite   then to_s_sqlite
        when :sqlserver then to_s_sqlserver
        end
      end

      private

      def to_s_sqlserver
        sql.gsub!(SQLSERVER_EXECUTESQL, '\1')
        sql.gsub!(SQLSERVER_REMOVE_INTEGERS, '?')
        sql.gsub!(SQLSERVER_IN_CLAUSE, 'IN (?)')
        sql
      end

      def to_s_postgres
        sql.gsub!(PSQL_PLACEHOLDER, '?')
        sql.gsub!(PSQL_VAR_INTERPOLATION, '')
        sql.gsub!(PSQL_AFTER_WHERE) {|c| c.gsub(PSQL_REMOVE_STRINGS, '?')}
        sql.gsub!(PSQL_REMOVE_INTEGERS, '?')
        sql.gsub!(PSQL_IN_CLAUSE, 'IN (?)')
        sql.gsub!(MULTIPLE_SPACES, ' ')
        sql.strip!
        sql
      end

      def to_s_mysql
        sql.gsub!(MYSQL_VAR_INTERPOLATION, '')
        sql.gsub!(MYSQL_REMOVE_SINGLE_QUOTE_STRINGS, '?')
        sql.gsub!(MYSQL_REMOVE_DOUBLE_QUOTE_STRINGS, '?')
        sql.gsub!(MYSQL_REMOVE_INTEGERS, '?')
        sql.gsub!(MYSQL_IN_CLAUSE, 'IN (?)')
        sql.gsub!(MULTIPLE_QUESTIONS, '?')
        sql.strip!
        sql
      end

      def to_s_sqlite
        sql.gsub!(SQLITE_VAR_INTERPOLATION, '')
        sql.gsub!(SQLITE_REMOVE_STRINGS, '?')
        sql.gsub!(SQLITE_REMOVE_INTEGERS, '?')
        sql.gsub!(MULTIPLE_SPACES, ' ')
        sql.strip!
        sql
      end

      def has_encodings?(encodings = %w[UTF-8 binary])
        encodings.all? { |enc| Encoding.find(enc) rescue false }
      end

      MAX_SQL_LENGTH = 16384

      def scrubbed(str)
        # safeguard - don't sanitize or scrub large SQL statements
        return '' if !str.is_a?(String) || str.length > MAX_SQL_LENGTH

        # Whatever encoding it is, it is valid and we can operate on it
        return str if str.valid_encoding? 

        # Prefer scrub over convert
        if str.respond_to?(:scrub)
          return str.scrub('_')
        elsif has_encodings?(['UTF-8', 'binary'])
          return str.encode('UTF-8', 'binary', :invalid => :replace, :undef => :replace, :replace => '_')
        end

        # Unable to scrub invalid sql encoding, returning empty string
        ''
      end
    end
  end
end
