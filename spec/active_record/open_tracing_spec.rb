# frozen_string_literal: true

RSpec.describe ActiveRecord::OpenTracing do
  # rubocop:disable RSpec/LeakyConstantDeclaration
  config = {
    ActiveRecord::ConnectionHandling::DEFAULT_ENV.call => {
      primary: {
        adapter: "sqlite3",
        database: "tracer-test",
        username: "writer",
        host: "db-writer"
      },
      primary_replica: {
        adapter: "sqlite3",
        database: "tracer-test",
        username: "reader",
        host: "db-reader"
      }
    }
  }
  ActiveRecord::Base.configurations = config

  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    connects_to database: { writing: :primary, reading: :primary_replica }
  end

  class User < ApplicationRecord
  end
  # rubocop:enable RSpec/LeakyConstantDeclaration

  before do
    ActiveRecord::Base.establish_connection
    ActiveRecord::Base.connection.execute "DROP TABLE IF EXISTS users"
    ActiveRecord::Base.connection.execute <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        id integer PRIMARY KEY,
        name text NOT NULL
      );
    SQL
    User.first  # load table schema, etc
  end

  let(:tracer) { OpenTracingTestTracer.build }

  it "records sql select query" do
    described_class.instrument(tracer: tracer)

    User.first

    expect(tracer.spans.count).to eq(1)
    span = tracer.spans.last
    expect(span.operation_name).to eq("User Load")
    expect(span.tags).to eq(
      "component" => "ActiveRecord",
      "span.kind" => "client",
      "db.instance" => "tracer-test",
      "db.query_category" => "read",
      "db.query_type" => "select",
      "db.statement" => 'SELECT "users".* FROM "users" ORDER BY "users"."id" ASC LIMIT ?',
      "db.cached" => false,
      "db.type" => "sql",
      "db.role" => "writing",
      "peer.address" => "sqlite3://writer@db-writer/tracer-test"
    )
  end

  it "uses active span as parent when present" do
    described_class.instrument(tracer: tracer)

    parent_span = tracer.start_active_span("parent_span") { User.first }.span

    expect(tracer.spans.count).to eq(2)
    span = tracer.spans.last
    expect(span.context.parent_id).to eq(parent_span.context.span_id)
  end

  it "records custom sql query" do
    described_class.instrument(tracer: tracer)

    ActiveRecord::Base.connection.execute "SELECT COUNT(1) FROM users"

    expect(tracer.spans.count).to eq(1)
    span = tracer.spans.last
    expect(span.operation_name).to eq("sql.query")
    expect(span.tags).to eq(
      "component" => "ActiveRecord",
      "span.kind" => "client",
      "db.instance" => "tracer-test",
      "db.query_category" => "read",
      "db.query_type" => "select",
      "db.statement" => "SELECT COUNT(1) FROM users",
      "db.cached" => false,
      "db.type" => "sql",
      "db.role" => "writing",
      "peer.address" => "sqlite3://writer@db-writer/tracer-test"
    )
  end

  it "records sql errors" do
    described_class.instrument(tracer: tracer)

    thrown_exception = nil
    begin
      ActiveRecord::Base.connection.execute "SELECT * FROM users WHERE email IS NULL"
    rescue StandardError => e
      thrown_exception = e
    end

    expect(tracer.spans.count).to eq(1)
    span = tracer.spans.last
    expect(span.operation_name).to eq("sql.query")
    expect(span.tags).to eq(
      "component" => "ActiveRecord",
      "span.kind" => "client",
      "db.instance" => "tracer-test",
      "db.query_category" => "read",
      "db.query_type" => "select",
      "db.statement" => "SELECT * FROM users WHERE email IS NULL",
      "db.cached" => false,
      "db.type" => "sql",
      "db.role" => "writing",
      "peer.address" => "sqlite3://writer@db-writer/tracer-test",
      "error" => true
    )
    expect(span.logs).to include(
      a_hash_including(
        event: "error",
        'error.kind': thrown_exception.class.to_s,
        'error.object': thrown_exception,
        message: thrown_exception.message,
        stack: thrown_exception.backtrace.join("\n")
      )
    )
  end

  it "doesn't crash on an empty query" do
    described_class.instrument(tracer: tracer)

    thrown_exception = nil
    begin
      ActiveRecord::Base.connection.execute ""
    rescue StandardError => e
      thrown_exception = e
    end

    expect(tracer.spans.count).to eq(1)
    span = tracer.spans.last
    expect(span.operation_name).to eq("sql.query")
    expect(span.tags).to eq(
      "component" => "ActiveRecord",
      "span.kind" => "client",
      "db.instance" => "tracer-test",
      "db.query_category" => "not_found",
      "db.query_type" => "",
      "db.statement" => "",
      "db.cached" => false,
      "db.type" => "sql",
      "db.role" => "writing",
      "peer.address" => "sqlite3://writer@db-writer/tracer-test",
      "error" => true
    )
    expect(span.logs).to include(
      a_hash_including(
        event: "error",
        'error.kind': thrown_exception.class.to_s,
        'error.object': thrown_exception,
        message: thrown_exception.message,
        stack: thrown_exception.backtrace.join("\n")
      )
    )
  end

  context "multi db roles support" do
    it "traces queries on writer db" do
      ActiveRecord::Base.connected_to(role: :writing) do
        described_class.instrument(tracer: tracer)

        User.first

        span = tracer.spans.last
        expect(span.operation_name).to eq("User Load")
        expect(span.tags["db.role"]).to eq("writing")
        expect(span.tags["peer.address"]).to eq("sqlite3://writer@db-writer/tracer-test")
      end
    end

    it "traces queries on reader replicas" do
      ActiveRecord::Base.connected_to(role: :reading) do
        described_class.instrument(tracer: tracer)

        User.first

        span = tracer.spans.last
        expect(span.operation_name).to eq("User Load")
        expect(span.tags["db.role"]).to eq("reading")
        expect(span.tags["peer.address"]).to eq("sqlite3://reader@db-reader/tracer-test")
      end
    end
  end
end
