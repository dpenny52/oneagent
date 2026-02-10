defmodule OneAgent.WhatsAppTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.WhatsApp
  alias OneAgent.WhatsApp.Channel
  import OneAgent.WhatsAppFixtures
  import OneAgent.AgentsFixtures, except: [scope_fixture: 0]
  import OneAgent.CredentialsFixtures, except: [scope_fixture: 0]

  setup do
    scope = scope_fixture()
    %{scope: scope}
  end

  describe "list_channels/1" do
    test "returns channels for the user", %{scope: scope} do
      _channel = channel_fixture(scope)
      assert [%Channel{}] = WhatsApp.list_channels(scope)
    end

    test "does not return other users' channels", %{scope: scope} do
      _channel = channel_fixture(scope)
      other_scope = scope_fixture()
      assert [] = WhatsApp.list_channels(other_scope)
    end
  end

  describe "get_channel/2" do
    test "returns the channel if owned by user", %{scope: scope} do
      channel = channel_fixture(scope)
      assert {:ok, %Channel{id: id}} = WhatsApp.get_channel(scope, channel.id)
      assert id == channel.id
    end

    test "returns not_found for another user's channel", %{scope: scope} do
      channel = channel_fixture(scope)
      other_scope = scope_fixture()
      assert {:error, :not_found} = WhatsApp.get_channel(other_scope, channel.id)
    end
  end

  describe "create_channel/2" do
    test "creates a channel with valid attrs", %{scope: scope} do
      attrs = valid_channel_attributes(scope)
      assert {:ok, %Channel{} = channel} = WhatsApp.create_channel(scope, attrs)
      assert channel.phone_number_id == attrs["phone_number_id"]
      assert channel.verify_token != nil
      assert channel.active == true
    end

    test "auto-generates verify_token if not provided", %{scope: scope} do
      attrs = valid_channel_attributes(scope)
      assert {:ok, %Channel{verify_token: token}} = WhatsApp.create_channel(scope, attrs)
      assert is_binary(token) and byte_size(token) > 16
    end

    test "rejects if agent not owned by user", %{scope: scope} do
      other_scope = scope_fixture()
      other_agent = agent_fixture(other_scope)

      cred = credential_fixture(scope, %{
        "name" => "wa-cred-#{System.unique_integer([:positive])}",
        "service" => "whatsapp",
        "credential_type" => "custom",
        "value" => "test"
      })

      attrs = %{
        "agent_id" => other_agent.id,
        "credential_id" => cred.id,
        "phone_number_id" => "unowned_agent_test"
      }

      assert {:error, "Agent not found or not owned by you"} = WhatsApp.create_channel(scope, attrs)
    end

    test "rejects if credential not owned by user", %{scope: scope} do
      other_scope = scope_fixture()
      other_cred = credential_fixture(other_scope)
      agent = agent_fixture(scope)

      attrs = %{
        "agent_id" => agent.id,
        "credential_id" => other_cred.id,
        "phone_number_id" => "unowned_cred_test"
      }

      assert {:error, "Credential not found or not owned by you"} = WhatsApp.create_channel(scope, attrs)
    end

    test "rejects duplicate phone_number_id", %{scope: scope} do
      attrs = valid_channel_attributes(scope)
      assert {:ok, _} = WhatsApp.create_channel(scope, attrs)

      attrs2 = valid_channel_attributes(scope, %{"phone_number_id" => attrs["phone_number_id"]})
      assert {:error, %Ecto.Changeset{}} = WhatsApp.create_channel(scope, attrs2)
    end
  end

  describe "update_channel/3" do
    test "updates channel fields", %{scope: scope} do
      channel = channel_fixture(scope)

      assert {:ok, updated} =
               WhatsApp.update_channel(scope, channel, %{"active" => false, "display_phone_number" => "+9876543210"})

      assert updated.active == false
      assert updated.display_phone_number == "+9876543210"
    end
  end

  describe "delete_channel/1" do
    test "deletes the channel", %{scope: scope} do
      channel = channel_fixture(scope)
      assert {:ok, _} = WhatsApp.delete_channel(channel)
      assert {:error, :not_found} = WhatsApp.get_channel(scope, channel.id)
    end
  end

  describe "get_active_channel_by_phone_number_id/1" do
    test "returns active channel with preloads", %{scope: scope} do
      channel = channel_fixture(scope)
      found = WhatsApp.get_active_channel_by_phone_number_id(channel.phone_number_id)
      assert found.id == channel.id
      assert found.user != nil
      assert found.agent != nil
      assert found.credential != nil
    end

    test "returns nil for inactive channel", %{scope: scope} do
      channel = channel_fixture(scope)
      {:ok, _} = WhatsApp.update_channel(scope, channel, %{"active" => false})
      assert nil == WhatsApp.get_active_channel_by_phone_number_id(channel.phone_number_id)
    end

    test "returns nil for unknown phone_number_id" do
      assert nil == WhatsApp.get_active_channel_by_phone_number_id("nonexistent")
    end
  end

  describe "get_active_channel_by_agent_id/1" do
    test "returns active channel for agent", %{scope: scope} do
      channel = channel_fixture(scope)
      found = WhatsApp.get_active_channel_by_agent_id(channel.agent_id)
      assert found != nil
      assert found.id == channel.id
    end

    test "returns nil for inactive channel", %{scope: scope} do
      channel = channel_fixture(scope)
      {:ok, _} = WhatsApp.update_channel(scope, channel, %{"active" => false})
      assert nil == WhatsApp.get_active_channel_by_agent_id(channel.agent_id)
    end

    test "returns nil for unknown agent_id" do
      assert nil == WhatsApp.get_active_channel_by_agent_id(Ecto.UUID.generate())
    end
  end

  describe "get_channel_by_verify_token/1" do
    test "returns channel matching token", %{scope: scope} do
      channel = channel_fixture(scope)
      found = WhatsApp.get_channel_by_verify_token(channel.verify_token)
      assert found.id == channel.id
    end

    test "returns nil for unknown token" do
      assert nil == WhatsApp.get_channel_by_verify_token("bogus_token")
    end
  end
end
