defmodule OneAgent.Tools.ReadWebpageTest do
  use ExUnit.Case, async: true

  alias OneAgent.Tools.ReadWebpage

  describe "execute/2" do
    test "rejects URLs that fail SSRF validation" do
      assert {:error, _} = ReadWebpage.execute(%{"url" => "http://127.0.0.1"}, %{})
    end

    test "rejects private IP addresses" do
      assert {:error, _} = ReadWebpage.execute(%{"url" => "http://10.0.0.1"}, %{})
    end

    @tag :slow
    test "handles connection error gracefully" do
      result = ReadWebpage.execute(%{"url" => "http://192.0.2.1:1"}, %{})
      assert {:error, msg} = result
      assert msg =~ "Failed to fetch URL"
    end

    test "rejects non-http schemes" do
      assert {:error, _} = ReadWebpage.execute(%{"url" => "ftp://example.com"}, %{})
    end
  end
end
