defmodule OneAgent.TelegramFixtures do
  @moduledoc """
  Test helpers for creating entities via the `OneAgent.Telegram` context.
  """

  alias OneAgent.Telegram
  alias OneAgent.AccountsFixtures
  alias OneAgent.AgentsFixtures
  alias OneAgent.CredentialsFixtures

  def valid_channel_attributes(scope, attrs \\ %{}) do
    agent = AgentsFixtures.agent_fixture(scope)

    credential =
      CredentialsFixtures.credential_fixture(scope, %{
        "name" => "telegram-cred-#{System.unique_integer([:positive])}",
        "service" => "telegram",
        "credential_type" => "api_key",
        "value" => "#{System.unique_integer([:positive])}:AAF_test_bot_token_string"
      })

    Map.merge(
      %{
        "agent_id" => agent.id,
        "credential_id" => credential.id,
        "bot_id" => "#{System.unique_integer([:positive])}"
      },
      attrs
    )
  end

  def channel_fixture(scope, attrs \\ %{}) do
    attrs = valid_channel_attributes(scope, attrs)
    {:ok, channel} = Telegram.create_channel(scope, attrs)
    channel
  end

  def scope_fixture do
    user = AccountsFixtures.confirmed_user_fixture()
    OneAgent.Accounts.Scope.for_user(user)
  end

  def webhook_payload(chat_id \\ 12345, text \\ "Hello agent") do
    %{
      "update_id" => System.unique_integer([:positive]),
      "message" => %{
        "message_id" => System.unique_integer([:positive]),
        "from" => %{
          "id" => chat_id,
          "is_bot" => false,
          "first_name" => "Test",
          "username" => "testuser"
        },
        "chat" => %{
          "id" => chat_id,
          "first_name" => "Test",
          "username" => "testuser",
          "type" => "private"
        },
        "date" => System.os_time(:second),
        "text" => text
      }
    }
  end
end
