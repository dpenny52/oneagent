defmodule OneAgent.EVM.CredentialsTest do
  use ExUnit.Case, async: true

  alias OneAgent.EVM.Credentials

  describe "parse_private_key/1" do
    test "parses valid JSON credential" do
      json = Jason.encode!(%{"private_key" => "0xabc123"})
      assert {:ok, "0xabc123"} = Credentials.parse_private_key(json)
    end

    test "returns error for nil" do
      assert {:error, msg} = Credentials.parse_private_key(nil)
      assert msg =~ "No EVM credential"
    end

    test "returns error for invalid JSON" do
      assert {:error, msg} = Credentials.parse_private_key("not json")
      assert msg =~ "Invalid credential JSON"
    end

    test "returns error for missing private_key" do
      json = Jason.encode!(%{"wrong_key" => "0x123"})
      assert {:error, msg} = Credentials.parse_private_key(json)
      assert msg =~ "Invalid credential format"
    end

    test "returns error for empty private_key" do
      json = Jason.encode!(%{"private_key" => ""})
      assert {:error, msg} = Credentials.parse_private_key(json)
      assert msg =~ "Invalid credential format"
    end
  end

  describe "parse_and_derive/1" do
    test "returns error for nil credential" do
      assert {:error, _} = Credentials.parse_and_derive(nil)
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Credentials.parse_and_derive("not json")
    end

    test "parses and derives address from valid key" do
      # Well-known test key
      key = "4c0883a69102937d6231471b5dbb6204fe512961708279f9d92b4d187114d7a5"
      json = Jason.encode!(%{"private_key" => "0x" <> key})
      assert {:ok, %{private_key: "0x" <> ^key, address: "0x" <> _}} = Credentials.parse_and_derive(json)
    end
  end
end
