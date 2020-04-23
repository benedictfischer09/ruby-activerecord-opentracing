# frozen_string_literal: true

module ActiveRecord
  module OpenTracing
    module SqlRegex
      MULTIPLE_SPACES    = /\s+/.freeze
      MULTIPLE_QUESTIONS = /\?(,\?)+/.freeze

      PSQL_VAR_INTERPOLATION = /\[\[.*\]\]\s*$/.freeze
      PSQL_REMOVE_STRINGS = /'(?:[^']|'')*'/.freeze
      PSQL_REMOVE_INTEGERS = /(?<!LIMIT )\b\d+\b/.freeze
      PSQL_PLACEHOLDER = /\$\d+/.freeze
      PSQL_IN_CLAUSE = /IN\s+\(\?[^\)]*\)/.freeze
      PSQL_AFTER_WHERE = /(?:WHERE\s+).*?(?:SELECT|$)/i.freeze

      MYSQL_VAR_INTERPOLATION = /\[\[.*\]\]\s*$/.freeze
      MYSQL_REMOVE_INTEGERS = /(?<!LIMIT )\b\d+\b/.freeze
      MYSQL_REMOVE_SINGLE_QUOTE_STRINGS = /'(?:\\'|[^']|'')*'/.freeze
      MYSQL_REMOVE_DOUBLE_QUOTE_STRINGS = /"(?:\\"|[^"]|"")*"/.freeze
      MYSQL_IN_CLAUSE = /IN\s+\(\?[^\)]*\)/.freeze

      SQLITE_VAR_INTERPOLATION = /\[\[.*\]\]\s*$/.freeze
      SQLITE_REMOVE_STRINGS = /'(?:[^']|'')*'/.freeze
      SQLITE_REMOVE_INTEGERS = /(?<!LIMIT )\b\d+\b/.freeze

      SQLSERVER_EXECUTESQL = /EXEC sp_executesql N'(.*?)'.*/.freeze
      SQLSERVER_REMOVE_INTEGERS = /(?<!LIMIT )\b(?<!@)\d+\b/.freeze
      SQLSERVER_IN_CLAUSE = /IN\s+\(\?[^\)]*\)/.freeze

      PSQL_SUBSTITUTIONS = [
        [PSQL_PLACEHOLDER, "?"],
        [PSQL_VAR_INTERPOLATION, ""],
        [PSQL_AFTER_WHERE, ->(c) { c.gsub(PSQL_REMOVE_STRINGS, "?") }],
        [PSQL_REMOVE_INTEGERS, "?"],
        [PSQL_IN_CLAUSE, "IN (?)"],
        [MULTIPLE_SPACES, " "]
      ].freeze

      MYSQL_SUBSTITUTIONS = [
        [MYSQL_VAR_INTERPOLATION, ""],
        [MYSQL_REMOVE_SINGLE_QUOTE_STRINGS, "?"],
        [MYSQL_REMOVE_DOUBLE_QUOTE_STRINGS, "?"],
        [MYSQL_REMOVE_INTEGERS, "?"],
        [MYSQL_IN_CLAUSE, "IN (?)"],
        [MULTIPLE_QUESTIONS, "?"]
      ].freeze

      SQLITE_SUBSTITUTIONS = [
        [SQLITE_VAR_INTERPOLATION, ""],
        [SQLITE_REMOVE_STRINGS, "?"],
        [SQLITE_REMOVE_INTEGERS, "?"],
        [MULTIPLE_SPACES, " "]
      ].freeze

      SQLSERVER_SUBSTITUTIONS = [
        [SQLSERVER_EXECUTESQL, '\1'],
        [SQLSERVER_REMOVE_INTEGERS, "?"],
        [SQLSERVER_IN_CLAUSE, "IN (?)"]
      ].freeze

      SUBSTITUTIONS = {
        postgres: PSQL_SUBSTITUTIONS,
        mysql: MYSQL_SUBSTITUTIONS,
        sqlite: SQLITE_SUBSTITUTIONS,
        sqlserver: SQLSERVER_SUBSTITUTIONS
      }.freeze
    end
  end
end
