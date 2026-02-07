defmodule OneAgent.TextUtils do
  @moduledoc """
  Shared text utilities for truncation and formatting across tools.
  """

  @truncation_suffix "\n... [truncated]"

  @doc """
  Truncates text to `max_bytes` bytes, appending a truncation indicator if needed.
  Uses `byte_size/1` for measurement — appropriate for API responses and raw data.
  """
  def truncate_bytes(text, max_bytes) when is_binary(text) do
    if byte_size(text) > max_bytes do
      String.slice(text, 0, max_bytes) <> @truncation_suffix
    else
      text
    end
  end

  @doc """
  Truncates text to `max_chars` characters, appending a truncation indicator if needed.
  Uses `String.length/1` for measurement — appropriate for human-readable text content.
  """
  def truncate_chars(text, max_chars) when is_binary(text) do
    if String.length(text) > max_chars do
      String.slice(text, 0, max_chars) <> @truncation_suffix
    else
      text
    end
  end
end
