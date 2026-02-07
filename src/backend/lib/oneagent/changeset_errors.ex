defmodule OneAgent.ChangesetErrors do
  @moduledoc """
  Formats Ecto changeset errors into human-readable strings for tool responses.
  """

  @doc """
  Traverses changeset errors and returns a formatted string like:
  "field: message1, message2; other_field: message3"

  Interpolates validation parameters (e.g. %{count} → actual value).
  """
  def format(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end
end
