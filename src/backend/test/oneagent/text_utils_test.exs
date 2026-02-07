defmodule OneAgent.TextUtilsTest do
  use ExUnit.Case, async: true

  alias OneAgent.TextUtils

  describe "truncate_bytes/2" do
    test "returns text unchanged when under limit" do
      text = "hello world"
      assert TextUtils.truncate_bytes(text, 100) == text
    end

    test "returns text unchanged when exactly at limit" do
      text = "12345"
      assert TextUtils.truncate_bytes(text, 5) == text
    end

    test "truncates and appends indicator when over limit" do
      text = String.duplicate("a", 200)
      result = TextUtils.truncate_bytes(text, 100)
      assert String.starts_with?(result, String.duplicate("a", 100))
      assert String.ends_with?(result, "\n... [truncated]")
    end

    test "measures by byte size, not character count" do
      # "é" is 2 bytes in UTF-8
      text = String.duplicate("é", 60)
      # 60 chars × 2 bytes = 120 bytes
      assert byte_size(text) == 120

      # Limit to 100 bytes — should truncate
      result = TextUtils.truncate_bytes(text, 100)
      assert String.ends_with?(result, "\n... [truncated]")
    end

    test "does not truncate when multi-byte text is under byte limit" do
      text = String.duplicate("é", 40)
      # 40 chars × 2 bytes = 80 bytes
      assert TextUtils.truncate_bytes(text, 100) == text
    end

    test "handles empty string" do
      assert TextUtils.truncate_bytes("", 100) == ""
    end

    test "truncates at 1 byte limit" do
      result = TextUtils.truncate_bytes("abc", 1)
      assert result == "a\n... [truncated]"
    end
  end

  describe "truncate_chars/2" do
    test "returns text unchanged when under limit" do
      text = "hello world"
      assert TextUtils.truncate_chars(text, 100) == text
    end

    test "returns text unchanged when exactly at limit" do
      text = "12345"
      assert TextUtils.truncate_chars(text, 5) == text
    end

    test "truncates and appends indicator when over limit" do
      text = String.duplicate("x", 200)
      result = TextUtils.truncate_chars(text, 50)
      assert String.starts_with?(result, String.duplicate("x", 50))
      assert String.ends_with?(result, "\n... [truncated]")
    end

    test "measures by character count, not byte size" do
      # "é" is 2 bytes but 1 character
      text = String.duplicate("é", 60)
      assert String.length(text) == 60

      # Limit to 100 chars — should NOT truncate (only 60 chars)
      assert TextUtils.truncate_chars(text, 100) == text
    end

    test "truncates multi-byte characters by char count" do
      text = String.duplicate("é", 60)
      result = TextUtils.truncate_chars(text, 50)
      assert String.ends_with?(result, "\n... [truncated]")
      # The prefix should be exactly 50 "é" characters
      prefix = String.replace_suffix(result, "\n... [truncated]", "")
      assert String.length(prefix) == 50
    end

    test "handles empty string" do
      assert TextUtils.truncate_chars("", 100) == ""
    end

    test "truncates at 1 character limit" do
      result = TextUtils.truncate_chars("abc", 1)
      assert result == "a\n... [truncated]"
    end
  end
end
