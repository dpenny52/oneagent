defmodule OneAgent.Repo.Migrations.AddMemoryFullTextSearch do
  use Ecto.Migration

  def up do
    # Add tsvector column for full-text search
    alter table(:agent_memories) do
      add :search_ts, :tsvector
    end

    # PL/pgSQL function to recursively extract all text from JSONB
    execute """
    CREATE OR REPLACE FUNCTION agent_memory_extract_text(val jsonb) RETURNS text AS $$
    DECLARE
      result text := '';
      item jsonb;
      key text;
    BEGIN
      IF val IS NULL THEN
        RETURN '';
      END IF;

      CASE jsonb_typeof(val)
        WHEN 'string' THEN
          RETURN val #>> '{}';
        WHEN 'number' THEN
          RETURN val::text;
        WHEN 'boolean' THEN
          RETURN val::text;
        WHEN 'array' THEN
          FOR item IN SELECT jsonb_array_elements(val) LOOP
            result := result || ' ' || agent_memory_extract_text(item);
          END LOOP;
          RETURN result;
        WHEN 'object' THEN
          FOR key, item IN SELECT * FROM jsonb_each(val) LOOP
            result := result || ' ' || key || ' ' || agent_memory_extract_text(item);
          END LOOP;
          RETURN result;
        ELSE
          RETURN '';
      END CASE;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """

    # Trigger to auto-build tsvector on insert/update
    execute """
    CREATE OR REPLACE FUNCTION agent_memory_search_trigger() RETURNS trigger AS $$
    BEGIN
      NEW.search_ts :=
        setweight(to_tsvector('english', coalesce(NEW.key, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.memory_type, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(agent_memory_extract_text(NEW.value::jsonb), '')), 'B');
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER agent_memory_search_update
      BEFORE INSERT OR UPDATE ON agent_memories
      FOR EACH ROW EXECUTE FUNCTION agent_memory_search_trigger();
    """

    # GIN index for fast full-text search
    create index(:agent_memories, [:search_ts], using: "GIN")

    # Backfill existing rows by touching updated_at (fires trigger)
    execute "UPDATE agent_memories SET updated_at = updated_at"
  end

  def down do
    execute "DROP TRIGGER IF EXISTS agent_memory_search_update ON agent_memories"
    execute "DROP FUNCTION IF EXISTS agent_memory_search_trigger()"
    execute "DROP FUNCTION IF EXISTS agent_memory_extract_text(jsonb)"

    drop_if_exists index(:agent_memories, [:search_ts])

    alter table(:agent_memories) do
      remove :search_ts
    end
  end
end
