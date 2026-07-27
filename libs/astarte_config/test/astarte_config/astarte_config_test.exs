defmodule Astarte.ConfigTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Astarte.Common.Generators.HTTP

  describe "url_env/4" do
    property "correctly creates base components" do
      check all url <- HTTP.url(), max_runs: 5 do
        %URI{
          scheme: scheme,
          host: host,
          port: port,
          path: path,
          query: query,
          fragment: fragment
        } = URI.parse(url)

        :ok = SampleConfig.put_my_service_scheme(scheme)
        :ok = SampleConfig.put_my_service_host(host)
        :ok = SampleConfig.put_my_service_port(port)
        :ok = SampleConfig.put_my_service_path(path)
        :ok = SampleConfig.put_my_service_query(query)
        :ok = SampleConfig.put_my_service_fragment(fragment)

        assert SampleConfig.my_service_scheme!() == scheme
        assert SampleConfig.my_service_host!() == host
        assert SampleConfig.my_service_port!() == port
        assert SampleConfig.my_service_path!() == path
        assert SampleConfig.my_service_query!() == query
        assert SampleConfig.my_service_fragment!() == fragment
      end
    end

    property "creates the url from base components" do
      check all url <- HTTP.url(), max_runs: 5 do
        %URI{
          scheme: scheme,
          host: host,
          port: port,
          path: path,
          query: query,
          fragment: fragment
        } = URI.parse(url)

        # we do not include the userinfo in the url
        expected_url =
          %URI{
            scheme: scheme,
            host: host,
            port: port,
            path: path,
            query: query,
            fragment: fragment
          }
          |> URI.to_string()

        assert :ok = SampleConfig.put_my_service_scheme(scheme)
        assert :ok = SampleConfig.put_my_service_host(host)
        assert :ok = SampleConfig.put_my_service_port(port)
        assert :ok = SampleConfig.put_my_service_path(path)
        assert :ok = SampleConfig.put_my_service_query(query)
        assert :ok = SampleConfig.put_my_service_fragment(fragment)
        SampleConfig.reload_my_service_url()

        assert SampleConfig.my_service_url!() == expected_url
      end
    end

    test "uses the correct scheme when using ssl with default scheme" do
      :ok = SampleConfig.put_ftp_service_ssl_enabled(false)
      SampleConfig.reload_ftp_service_scheme()
      assert "ftp" = SampleConfig.ftp_service_scheme!()

      :ok = SampleConfig.put_ftp_service_ssl_enabled(true)
      SampleConfig.reload_ftp_service_scheme()
      assert "ftps" = SampleConfig.ftp_service_scheme!()
    end

    test "uses the correct scheme when using ssl with custom scheme" do
      :ok = SampleConfig.put_custom_ssl_scheme_ssl_enabled(false)
      SampleConfig.reload_custom_ssl_scheme_scheme()
      assert "myscheme" = SampleConfig.custom_ssl_scheme_scheme!()

      :ok = SampleConfig.put_custom_ssl_scheme_ssl_enabled(true)
      SampleConfig.reload_custom_ssl_scheme_scheme()
      assert "myschemessl" = SampleConfig.custom_ssl_scheme_scheme!()
    end

    test "correctly creates default request options when ssl is disabled" do
      SampleConfig.put_my_service_ssl_enabled(false)
      SampleConfig.reload_my_service_request_opts()
      config = SampleConfig.my_service_request_opts!()
      assert Keyword.fetch!(config, :ssl) == []
    end

    test "correctly creates default request options when ssl is enabled and sni is disabled" do
      SampleConfig.put_my_service_ssl_enabled(true)
      SampleConfig.put_my_service_ssl_disable_sni(true)
      SampleConfig.reload_my_service_request_opts()
      config = SampleConfig.my_service_request_opts!()
      assert {:ok, ssl_config} = Keyword.fetch(config, :ssl)
      assert Keyword.fetch!(ssl_config, :verify) == :verify_peer
      assert Keyword.fetch!(ssl_config, :cacertfile) == SampleConfig.my_service_ssl_ca_file!()
      assert Keyword.fetch!(ssl_config, :server_name_indication) == :disable
    end

    test "correctly creates default request options when ssl is enabled using default sni" do
      SampleConfig.put_my_service_ssl_enabled(true)
      SampleConfig.put_my_service_ssl_disable_sni(false)
      SampleConfig.reload_my_service_host()
      SampleConfig.reload_my_service_port()
      SampleConfig.reload_my_service_path()
      SampleConfig.reload_my_service_query()
      SampleConfig.reload_my_service_fragment()
      SampleConfig.reload_my_service_url()
      SampleConfig.reload_my_service_ssl_custom_sni()
      SampleConfig.reload_my_service_request_opts()
      config = SampleConfig.my_service_request_opts!()

      expected =
        SampleConfig.my_service_url!()
        |> URI.parse()
        |> Map.fetch!(:host)

      assert {:ok, ssl_config} = Keyword.fetch(config, :ssl)
      assert Keyword.fetch!(ssl_config, :verify) == :verify_peer
      assert Keyword.fetch!(ssl_config, :cacertfile) == SampleConfig.my_service_ssl_ca_file!()
      assert Keyword.fetch!(ssl_config, :server_name_indication) == to_charlist(expected)
    end

    test "correctly creates default request options when ssl is enabled using custom sni" do
      custom_sni = "custom"
      SampleConfig.put_my_service_ssl_enabled(true)
      SampleConfig.put_my_service_ssl_disable_sni(false)
      SampleConfig.put_my_service_ssl_custom_sni(custom_sni)
      SampleConfig.reload_my_service_request_opts()
      config = SampleConfig.my_service_request_opts!()

      assert {:ok, ssl_config} = Keyword.fetch(config, :ssl)
      assert Keyword.fetch!(ssl_config, :verify) == :verify_peer
      assert Keyword.fetch!(ssl_config, :cacertfile) == SampleConfig.my_service_ssl_ca_file!()
      assert Keyword.fetch!(ssl_config, :server_name_indication) == to_charlist(custom_sni)
    end

    test "correctly creates default request options for authenticated requests" do
      config = SampleConfig.amqp_management_service_request_opts!()
      assert {:ok, hackney_config} = Keyword.fetch(config, :hackney)
      assert {:ok, {"guest", "guest"}} = Keyword.fetch(hackney_config, :basic_auth)
    end

    test "correctly sets default port when set" do
      SampleConfig.reload_ftp_service_port()
      assert SampleConfig.ftp_service_port!() == 8080
    end

    test "adds basic auth to request options only when username and password are set" do
      SampleConfig.put_my_service_username(nil)
      SampleConfig.put_my_service_password(nil)
      SampleConfig.reload_my_service_request_opts()
      assert Keyword.has_key?(SampleConfig.my_service_request_opts!(), :hackney) == false

      SampleConfig.put_my_service_username("user")
      SampleConfig.put_my_service_password(nil)
      SampleConfig.reload_my_service_request_opts()
      assert Keyword.has_key?(SampleConfig.my_service_request_opts!(), :hackney) == false

      SampleConfig.put_my_service_username(nil)
      SampleConfig.put_my_service_password("pass")
      SampleConfig.reload_my_service_request_opts()
      assert Keyword.has_key?(SampleConfig.my_service_request_opts!(), :hackney) == false

      SampleConfig.put_my_service_username("user")
      SampleConfig.put_my_service_password("pass")
      SampleConfig.reload_my_service_request_opts()
      config = SampleConfig.my_service_request_opts!()
      assert {:ok, hackney_config} = Keyword.fetch(config, :hackney)
      assert {:ok, {"user", "pass"}} = Keyword.fetch(hackney_config, :basic_auth)
    end

    test "uses the whole url when set, ignoring the components" do
      SampleConfig.put_my_service_host("component.example")
      SampleConfig.put_my_service_url("http://override.example:9000")

      assert SampleConfig.my_service_url!() == "http://override.example:9000"
    end

    test "properly sets the url from _URL variable" do
      url = "https://example.com:8080/path"

      on_exit(fn ->
        System.delete_env("ASTARTE_MY_SERVICE_URL")
      end)

      System.put_env("ASTARTE_MY_SERVICE_URL", url)
      SampleConfig.reload_my_service_url()
      assert SampleConfig.my_service_url!() == url
    end

    test "properly sets the url from component variables" do
      url = "https://example.com:8080/path"

      %URI{
        scheme: scheme,
        host: host,
        port: port,
        path: path
      } = URI.parse(url)

      on_exit(fn ->
        System.delete_env("ASTARTE_MY_SERVICE_SCHEME")
        System.delete_env("ASTARTE_MY_SERVICE_HOST")
        System.delete_env("ASTARTE_MY_SERVICE_PORT")
        System.delete_env("ASTARTE_MY_SERVICE_PATH")
      end)

      System.put_env("ASTARTE_MY_SERVICE_SCHEME", scheme)
      System.put_env("ASTARTE_MY_SERVICE_HOST", host)
      System.put_env("ASTARTE_MY_SERVICE_PORT", to_string(port))
      System.put_env("ASTARTE_MY_SERVICE_PATH", path)

      SampleConfig.reload_my_service_scheme()
      SampleConfig.reload_my_service_host()
      SampleConfig.reload_my_service_port()
      SampleConfig.reload_my_service_path()
      SampleConfig.reload_my_service_query()
      SampleConfig.reload_my_service_fragment()
      SampleConfig.reload_my_service_url()

      assert SampleConfig.my_service_url!() == url
    end

    test "url environment variable takes precedence over component variables" do
      url_1 = "ftp://examlpe.com:8080/path"
      url_2 = "http://examlpe.com:9090/some/path"

      %URI{
        scheme: scheme,
        host: host,
        port: port,
        path: path
      } = URI.parse(url_1)

      on_exit(fn ->
        System.delete_env("ASTARTE_CONFIG_FTP_SERVICE_SCHEME")
        System.delete_env("ASTARTE_CONFIG_FTP_SERVICE_HOST")
        System.delete_env("ASTARTE_CONFIG_FTP_SERVICE_PORT")
        System.delete_env("ASTARTE_CONFIG_FTP_SERVICE_PATH")
        System.delete_env("ASTARTE_CONFIG_FTP_SERVICE_URL")
      end)

      System.put_env("ASTARTE_CONFIG_FTP_SERVICE_SCHEME", scheme)
      System.put_env("ASTARTE_CONFIG_FTP_SERVICE_HOST", host)
      System.put_env("ASTARTE_CONFIG_FTP_SERVICE_PORT", to_string(port))
      System.put_env("ASTARTE_CONFIG_FTP_SERVICE_PATH", path)
      System.put_env("ASTARTE_CONFIG_FTP_SERVICE_URL", url_2)

      SampleConfig.reload_ftp_service_scheme()
      SampleConfig.reload_ftp_service_host()
      SampleConfig.reload_ftp_service_port()
      SampleConfig.reload_ftp_service_path()
      SampleConfig.reload_ftp_service_query()
      SampleConfig.reload_ftp_service_fragment()
      SampleConfig.reload_ftp_service_url()

      assert SampleConfig.ftp_service_url!() == url_2
    end
  end
end
