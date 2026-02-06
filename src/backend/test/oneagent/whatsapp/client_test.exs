defmodule OneAgent.WhatsApp.ClientTest do
  use ExUnit.Case, async: true

  alias OneAgent.WhatsApp.Client

  describe "verify_signature/3" do
    test "returns :ok for valid signature" do
      body = ~s({"test": true})
      secret = "my_secret"

      hash =
        :crypto.mac(:hmac, :sha256, secret, body)
        |> Base.encode16(case: :lower)

      signature = "sha256=#{hash}"
      assert :ok = Client.verify_signature(body, signature, secret)
    end

    test "returns :error for invalid signature" do
      assert :error = Client.verify_signature("body", "sha256=bad", "secret")
    end

    test "returns :error for missing sha256= prefix" do
      assert :error = Client.verify_signature("body", "invalid_header", "secret")
    end

    test "returns :error for empty signature" do
      assert :error = Client.verify_signature("body", "", "secret")
    end
  end

  describe "parse_messages/1" do
    test "extracts text messages" do
      payload = %{
        "object" => "whatsapp_business_account",
        "entry" => [
          %{
            "id" => "WABA_ID",
            "changes" => [
              %{
                "value" => %{
                  "messaging_product" => "whatsapp",
                  "metadata" => %{
                    "display_phone_number" => "15550001111",
                    "phone_number_id" => "123456"
                  },
                  "messages" => [
                    %{
                      "from" => "15551234567",
                      "id" => "wamid.abc123",
                      "timestamp" => "1234567890",
                      "text" => %{"body" => "Hello there"},
                      "type" => "text"
                    }
                  ]
                },
                "field" => "messages"
              }
            ]
          }
        ]
      }

      assert [msg] = Client.parse_messages(payload)
      assert msg.from == "15551234567"
      assert msg.text == "Hello there"
      assert msg.phone_number_id == "123456"
      assert msg.message_id == "wamid.abc123"
    end

    test "ignores non-text messages (e.g. image)" do
      payload = %{
        "entry" => [
          %{
            "changes" => [
              %{
                "value" => %{
                  "metadata" => %{"phone_number_id" => "123"},
                  "messages" => [
                    %{
                      "from" => "1555",
                      "id" => "wamid.img",
                      "type" => "image",
                      "image" => %{"id" => "img_123"}
                    }
                  ]
                }
              }
            ]
          }
        ]
      }

      assert [] = Client.parse_messages(payload)
    end

    test "ignores status updates (no messages key)" do
      payload = %{
        "entry" => [
          %{
            "changes" => [
              %{
                "value" => %{
                  "metadata" => %{"phone_number_id" => "123"},
                  "statuses" => [
                    %{"id" => "wamid.xyz", "status" => "delivered"}
                  ]
                }
              }
            ]
          }
        ]
      }

      assert [] = Client.parse_messages(payload)
    end

    test "returns empty for nil/empty payload" do
      assert [] = Client.parse_messages(%{})
      assert [] = Client.parse_messages(nil)
    end

    test "handles multiple messages in one entry" do
      payload = %{
        "entry" => [
          %{
            "changes" => [
              %{
                "value" => %{
                  "metadata" => %{"phone_number_id" => "999"},
                  "messages" => [
                    %{"from" => "111", "id" => "m1", "type" => "text", "text" => %{"body" => "first"}},
                    %{"from" => "222", "id" => "m2", "type" => "text", "text" => %{"body" => "second"}}
                  ]
                }
              }
            ]
          }
        ]
      }

      assert [msg1, msg2] = Client.parse_messages(payload)
      assert msg1.text == "first"
      assert msg2.text == "second"
    end
  end
end
