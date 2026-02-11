defmodule OneAgent.TelegramTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Telegram
  alias OneAgent.Telegram.Channel
  import OneAgent.TelegramFixtures
  import OneAgent.AgentsFixtures, except: [scope_fixture: 0]
  import OneAgent.CredentialsFixtures, except: [scope_fixture: 0]

  setup do
    scope = scope_fixture()
    %{scope: scope}
  end

  describe "list_channels/1" do
    test "returns channels for the user", %{scope: scope} do
      _channel = channel_fixture(scope)
      assert [%Channel{}] = Telegram.list_channels(scope)
    end

    test "does not return other users' channels", %{scope: scope} do
      _channel = channel_fixture(scope)
      other_scope = scope_fixture()
      assert [] = Telegram.list_channels(other_scope)
    end
  end

  describe "get_channel/2" do
    test "returns the channel if owned by user", %{scope: scope} do
      channel = channel_fixture(scope)
      assert {:ok, %Channel{id: id}} = Telegram.get_channel(scope, channel.id)
      assert id == channel.id
    end

    test "returns not_found for another user's channel", %{scope: scope} do
      channel = channel_fixture(scope)
      other_scope = scope_fixture()
      assert {:error, :not_found} = Telegram.get_channel(other_scope, channel.id)
    end
  end

  describe "create_channel/2" do
    test "creates a channel with valid attrs", %{scope: scope} do
      attrs = valid_channel_attributes(scope)
      assert {:ok, %Channel{} = channel} = Telegram.create_channel(scope, attrs)
      assert channel.bot_id == attrs["bot_id"]
      assert channel.secret_token != nil
      assert channel.active == true
    end

    test "auto-generates secret_token if not provided", %{scope: scope} do
      attrs = valid_channel_attributes(scope)
      assert {:ok, %Channel{secret_token: token}} = Telegram.create_channel(scope, attrs)
      assert is_binary(token) and byte_size(token) > 16
    end

    test "rejects if agent not owned by user", %{scope: scope} do
      other_scope = scope_fixture()
      other_agent = agent_fixture(other_scope)

      cred =
        credential_fixture(scope, %{
          "name" => "tg-cred-#{System.unique_integer([:positive])}",
          "service" => "telegram",
          "credential_type" => "api_key",
          "value" => "test"
        })

      attrs = %{
        "agent_id" => other_agent.id,
        "credential_id" => cred.id,
        "bot_id" => "unowned_agent_test"
      }

      assert {:error, "Agent not found or not owned by you"} =
               Telegram.create_channel(scope, attrs)
    end

    test "rejects if credential not owned by user", %{scope: scope} do
      other_scope = scope_fixture()
      other_cred = credential_fixture(other_scope)
      agent = agent_fixture(scope)

      attrs = %{
        "agent_id" => agent.id,
        "credential_id" => other_cred.id,
        "bot_id" => "unowned_cred_test"
      }

      assert {:error, "Credential not found or not owned by you"} =
               Telegram.create_channel(scope, attrs)
    end

    test "rejects duplicate bot_id", %{scope: scope} do
      attrs = valid_channel_attributes(scope)
      assert {:ok, _} = Telegram.create_channel(scope, attrs)

      attrs2 = valid_channel_attributes(scope, %{"bot_id" => attrs["bot_id"]})
      assert {:error, %Ecto.Changeset{}} = Telegram.create_channel(scope, attrs2)
    end
  end

  describe "update_channel/3" do
    test "updates channel fields", %{scope: scope} do
      channel = channel_fixture(scope)

      assert {:ok, updated} =
               Telegram.update_channel(scope, channel, %{
                 "active" => false,
                 "bot_username" => "my_test_bot"
               })

      assert updated.active == false
      assert updated.bot_username == "my_test_bot"
    end
  end

  describe "delete_channel/1" do
    test "deletes the channel", %{scope: scope} do
      channel = channel_fixture(scope)
      assert {:ok, _} = Telegram.delete_channel(channel)
      assert {:error, :not_found} = Telegram.get_channel(scope, channel.id)
    end
  end

  describe "get_channel_by_bot_id/1" do
    test "returns active channel with preloads", %{scope: scope} do
      channel = channel_fixture(scope)
      found = Telegram.get_channel_by_bot_id(channel.bot_id)
      assert found.id == channel.id
      assert found.user != nil
      assert found.agent != nil
      assert found.credential != nil
    end

    test "returns nil for inactive channel", %{scope: scope} do
      channel = channel_fixture(scope)
      {:ok, _} = Telegram.update_channel(scope, channel, %{"active" => false})
      assert nil == Telegram.get_channel_by_bot_id(channel.bot_id)
    end

    test "returns nil for unknown bot_id" do
      assert nil == Telegram.get_channel_by_bot_id("nonexistent")
    end
  end

  describe "get_channel_by_agent/1" do
    test "returns active channel for agent", %{scope: scope} do
      channel = channel_fixture(scope)
      found = Telegram.get_channel_by_agent(channel.agent_id)
      assert found != nil
      assert found.id == channel.id
    end

    test "returns nil for inactive channel", %{scope: scope} do
      channel = channel_fixture(scope)
      {:ok, _} = Telegram.update_channel(scope, channel, %{"active" => false})
      assert nil == Telegram.get_channel_by_agent(channel.agent_id)
    end

    test "returns nil for unknown agent_id" do
      assert nil == Telegram.get_channel_by_agent(Ecto.UUID.generate())
    end
  end
end
