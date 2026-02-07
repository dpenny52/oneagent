defmodule OneAgent.Tools.UrlValidatorTest do
  use ExUnit.Case, async: true

  alias OneAgent.Tools.UrlValidator

  describe "validate/1" do
    test "accepts valid http URL" do
      assert :ok = UrlValidator.validate("http://example.com")
    end

    test "accepts valid https URL" do
      assert :ok = UrlValidator.validate("https://example.com/path?q=1")
    end

    test "rejects non-http scheme" do
      assert {:error, msg} = UrlValidator.validate("ftp://example.com")
      assert msg =~ "http or https"
      assert msg =~ "ftp"
    end

    test "rejects file:// scheme" do
      assert {:error, msg} = UrlValidator.validate("file:///etc/passwd")
      assert msg =~ "http or https"
    end

    test "rejects URL with no scheme" do
      assert {:error, msg} = UrlValidator.validate("example.com")
      assert msg =~ "http or https"
    end

    test "rejects URL with no host" do
      assert {:error, msg} = UrlValidator.validate("http://")
      assert msg =~ "host"
    end

    test "rejects localhost" do
      assert {:error, msg} = UrlValidator.validate("http://localhost/api")
      assert msg =~ "not allowed"
    end

    test "rejects 127.0.0.1 (loopback)" do
      assert {:error, msg} = UrlValidator.validate("http://127.0.0.1/api")
      assert msg =~ "private"
    end

    test "rejects 127.0.0.2 (full loopback range)" do
      assert {:error, msg} = UrlValidator.validate("http://127.0.0.2")
      assert msg =~ "private"
    end

    test "rejects 10.x.x.x (private class A)" do
      assert {:error, msg} = UrlValidator.validate("http://10.0.0.1")
      assert msg =~ "private"
    end

    test "rejects 172.16.x.x (private class B)" do
      assert {:error, msg} = UrlValidator.validate("http://172.16.0.1")
      assert msg =~ "private"
    end

    test "rejects 172.31.x.x (private class B upper)" do
      assert {:error, msg} = UrlValidator.validate("http://172.31.255.255")
      assert msg =~ "private"
    end

    test "accepts 172.15.x.x (not private)" do
      assert :ok = UrlValidator.validate("http://172.15.0.1")
    end

    test "accepts 172.32.x.x (not private)" do
      assert :ok = UrlValidator.validate("http://172.32.0.1")
    end

    test "rejects 192.168.x.x (private class C)" do
      assert {:error, msg} = UrlValidator.validate("http://192.168.1.1")
      assert msg =~ "private"
    end

    test "rejects 169.254.x.x (link-local / cloud metadata)" do
      assert {:error, msg} = UrlValidator.validate("http://169.254.169.254/latest/meta-data/")
      assert msg =~ "private"
    end

    test "rejects 0.0.0.0" do
      assert {:error, msg} = UrlValidator.validate("http://0.0.0.0")
      assert msg =~ "private"
    end

    test "rejects metadata.google.internal" do
      assert {:error, msg} = UrlValidator.validate("http://metadata.google.internal/computeMetadata/v1/")
      assert msg =~ "not allowed"
    end

    test "rejects non-string input" do
      assert {:error, msg} = UrlValidator.validate(nil)
      assert msg =~ "string"
    end

    test "rejects integer input" do
      assert {:error, msg} = UrlValidator.validate(123)
      assert msg =~ "string"
    end

    # IPv6 SSRF bypass vectors

    test "rejects IPv6-mapped loopback (::ffff:127.0.0.1)" do
      assert {:error, msg} = UrlValidator.validate("http://[::ffff:127.0.0.1]/api")
      assert msg =~ "private"
    end

    test "rejects IPv6-mapped private 10.x (::ffff:10.0.0.1)" do
      assert {:error, msg} = UrlValidator.validate("http://[::ffff:10.0.0.1]")
      assert msg =~ "private"
    end

    test "rejects IPv6-mapped private 172.16.x (::ffff:172.16.0.1)" do
      assert {:error, msg} = UrlValidator.validate("http://[::ffff:172.16.0.1]")
      assert msg =~ "private"
    end

    test "rejects IPv6-mapped private 192.168.x (::ffff:192.168.1.1)" do
      assert {:error, msg} = UrlValidator.validate("http://[::ffff:192.168.1.1]")
      assert msg =~ "private"
    end

    test "rejects IPv6-mapped link-local metadata (::ffff:169.254.169.254)" do
      assert {:error, msg} = UrlValidator.validate("http://[::ffff:169.254.169.254]/latest/meta-data/")
      assert msg =~ "private"
    end

    test "rejects IPv6-mapped 0.0.0.0 (::ffff:0.0.0.0)" do
      assert {:error, msg} = UrlValidator.validate("http://[::ffff:0.0.0.0]")
      assert msg =~ "private"
    end

    test "accepts IPv6-mapped public IP (::ffff:8.8.8.8)" do
      assert :ok = UrlValidator.validate("http://[::ffff:8.8.8.8]")
    end

    test "rejects IPv6 link-local (fe80::1)" do
      assert {:error, msg} = UrlValidator.validate("http://[fe80::1]")
      assert msg =~ "private"
    end

    test "rejects IPv6 unique-local (fc00::1)" do
      assert {:error, msg} = UrlValidator.validate("http://[fc00::1]")
      assert msg =~ "private"
    end

    test "rejects IPv6 unique-local (fd00::1)" do
      assert {:error, msg} = UrlValidator.validate("http://[fd00::1]")
      assert msg =~ "private"
    end

    test "rejects IPv6 loopback (::1)" do
      assert {:error, msg} = UrlValidator.validate("http://[::1]")
      assert msg =~ "private"
    end

    test "accepts public IPv6 address" do
      assert :ok = UrlValidator.validate("http://[2607:f8b0:4004:800::200e]")
    end
  end
end
