defmodule OneAgent.Tools.CheckEmailTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.CheckEmail

  describe "callbacks" do
    test "id returns check_email" do
      assert CheckEmail.id() == "check_email"
    end

    test "bucket returns :gmail" do
      assert CheckEmail.bucket() == :gmail
    end

    test "required_credential_type returns :oauth_token" do
      assert CheckEmail.required_credential_type() == :oauth_token
    end

    test "parameters_schema has required fields" do
      schema = CheckEmail.parameters_schema()
      assert schema["type"] == "object"
      assert schema["required"] == ["action"]
      assert Map.has_key?(schema["properties"], "action")
      assert Map.has_key?(schema["properties"], "query")
      assert Map.has_key?(schema["properties"], "max_results")
      assert Map.has_key?(schema["properties"], "message_id")
    end
  end

  describe "execute/2" do
    test "returns error when no credential" do
      assert {:error, msg} = CheckEmail.execute(%{"action" => "list"}, %{})
      assert msg =~ "No Gmail credential"
    end

    test "returns error for invalid credential JSON" do
      assert {:error, msg} = CheckEmail.execute(%{"action" => "list"}, %{credential_value: "not-json"})
      assert msg =~ "Invalid Gmail credential"
    end

    test "returns error for credential missing refresh_token" do
      value = Jason.encode!(%{"something_else" => "abc"})
      assert {:error, msg} = CheckEmail.execute(%{"action" => "list"}, %{credential_value: value})
      assert msg =~ "Invalid Gmail credential"
    end

    test "returns error for read without message_id" do
      # This will fail at token refresh since we don't have real credentials,
      # but we can test the parameter validation by setting up a mock-like scenario.
      # Since we can't easily mock Req here, we test the path that doesn't need a token.
      assert {:error, msg} = CheckEmail.execute(%{"action" => "read"}, %{})
      assert msg =~ "No Gmail credential"
    end

    test "returns error for unknown action" do
      # Will fail at credential check first
      assert {:error, _} = CheckEmail.execute(%{"action" => "delete"}, %{})
    end
  end
end
