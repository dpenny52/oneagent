defmodule OneAgent.WhatsAppFixtures do
  @moduledoc """
  Test helpers for creating entities via the `OneAgent.WhatsApp` context.
  """

  alias OneAgent.WhatsApp
  alias OneAgent.AccountsFixtures
  alias OneAgent.AgentsFixtures
  alias OneAgent.CredentialsFixtures

  def valid_channel_attributes(scope, attrs \\ %{}) do
    agent = AgentsFixtures.agent_fixture(scope)

    credential =
      CredentialsFixtures.credential_fixture(scope, %{
        "name" => "whatsapp-cred-#{System.unique_integer([:positive])}",
        "service" => "whatsapp",
        "credential_type" => "custom",
        "value" => Jason.encode!(%{"access_token" => "EAAx_test_token", "app_secret" => "test_app_secret_123"})
      })

    Map.merge(
      %{
        "agent_id" => agent.id,
        "credential_id" => credential.id,
        "phone_number_id" => "#{System.unique_integer([:positive])}",
        "display_phone_number" => "+1234567890"
      },
      attrs
    )
  end

  def channel_fixture(scope, attrs \\ %{}) do
    attrs = valid_channel_attributes(scope, attrs)

    {:ok, channel} = WhatsApp.create_channel(scope, attrs)
    channel
  end

  def scope_fixture do
    user = AccountsFixtures.confirmed_user_fixture()
    OneAgent.Accounts.Scope.for_user(user)
  end

  @doc """
  Builds a realistic Meta webhook payload for a text message.
  """
  def webhook_payload(phone_number_id, from \\ "15551234567", text \\ "Hello agent") do
    %{
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
                  "phone_number_id" => phone_number_id
                },
                "contacts" => [
                  %{"profile" => %{"name" => "Test User"}, "wa_id" => from}
                ],
                "messages" => [
                  %{
                    "from" => from,
                    "id" => "wamid.test_#{System.unique_integer([:positive])}",
                    "timestamp" => "#{System.os_time(:second)}",
                    "text" => %{"body" => text},
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
  end

  @doc """
  Computes the HMAC-SHA256 signature for a given body and secret.
  """
  def compute_signature(body, app_secret) do
    hash =
      :crypto.mac(:hmac, :sha256, app_secret, body)
      |> Base.encode16(case: :lower)

    "sha256=#{hash}"
  end
end
