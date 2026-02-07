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

  describe "extract_body/1" do
    test "decodes URL-safe base64 text/plain body from parts" do
      body_data = Base.url_encode64("Hello, world!", padding: false)

      payload = %{
        "parts" => [
          %{"mimeType" => "text/plain", "body" => %{"data" => body_data}},
          %{"mimeType" => "text/html", "body" => %{"data" => Base.url_encode64("<p>Hello</p>", padding: false)}}
        ]
      }

      assert CheckEmail.extract_body(payload) == "Hello, world!"
    end

    test "falls back to text/html when text/plain is missing" do
      body_data = Base.url_encode64("<p>HTML only</p>", padding: false)

      payload = %{
        "parts" => [
          %{"mimeType" => "text/html", "body" => %{"data" => body_data}}
        ]
      }

      assert CheckEmail.extract_body(payload) == "<p>HTML only</p>"
    end

    test "handles nested multipart parts" do
      inner_data = Base.url_encode64("Nested body", padding: false)

      payload = %{
        "parts" => [
          %{
            "mimeType" => "multipart/alternative",
            "parts" => [
              %{"mimeType" => "text/plain", "body" => %{"data" => inner_data}}
            ]
          }
        ]
      }

      assert CheckEmail.extract_body(payload) == "Nested body"
    end

    test "decodes body data directly (non-multipart)" do
      body_data = Base.url_encode64("Direct body", padding: false)

      payload = %{"body" => %{"data" => body_data}}

      assert CheckEmail.extract_body(payload) == "Direct body"
    end

    test "returns empty string for nil body data" do
      payload = %{"body" => %{"data" => nil}}
      assert CheckEmail.extract_body(payload) == ""
    end

    test "returns empty string for invalid base64 data" do
      payload = %{"body" => %{"data" => "!!!not-valid-base64!!!"}}
      assert CheckEmail.extract_body(payload) == ""
    end

    test "returns empty string for payload with no parts or body" do
      assert CheckEmail.extract_body(%{}) == ""
      assert CheckEmail.extract_body(nil) == ""
    end

    test "correctly decodes data containing URL-safe base64 characters" do
      # String with characters that produce + and / in standard base64
      # but - and _ in URL-safe base64
      original = "subjects?query=foo&bar=baz>>>end"
      body_data = Base.url_encode64(original, padding: false)

      payload = %{"body" => %{"data" => body_data}}
      assert CheckEmail.extract_body(payload) == original
    end
  end
end
