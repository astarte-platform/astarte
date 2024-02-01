#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.DataUpdaterPlant.AMQPOptionsTest do
  use ExUnit.Case
  alias Astarte.DataUpdaterPlant.Config

  defp reset_to_defaults do
    Config.reload_amqp_consumer_password()
    Config.reload_amqp_consumer_username()
    Config.reload_amqp_consumer_port()
    Config.reload_amqp_consumer_host()
    Config.reload_amqp_consumer_virtual_host()
    Config.reload_amqp_consumer_ssl_enabled()
    Config.reload_amqp_consumer_ssl_ca_file()
    Config.reload_amqp_consumer_ssl_disable_sni()
    Config.reload_amqp_consumer_ssl_custom_sni()

    Config.reload_amqp_producer_password()
    Config.reload_amqp_producer_username()
    Config.reload_amqp_producer_port()
    Config.reload_amqp_producer_host()
    Config.reload_amqp_producer_virtual_host()
    Config.reload_amqp_producer_ssl_enabled()
    Config.reload_amqp_producer_ssl_ca_file()
    Config.reload_amqp_producer_ssl_disable_sni()
    Config.reload_amqp_producer_ssl_custom_sni()
  end

  setup do
    on_exit(&reset_to_defaults/0)
  end

  describe "amqp consumer options when ssl is enabled" do
    test "no ca_cert is set" do
      Config.put_amqp_consumer_ssl_enabled(true)

      ssl_options =
        Config.amqp_consumer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert cacertfile: CAStore.file_path() in ssl_options
    end

    test "ca_cert is set" do
      ca_cert_path = "/the/path/to/ca_cert.pem"
      Config.put_amqp_consumer_ssl_enabled(true)
      Config.put_amqp_consumer_ssl_ca_file(ca_cert_path)

      ssl_options =
        Config.amqp_consumer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert cacertfile: ca_cert_path in ssl_options
      assert server_name_indication: Config.amqp_consumer_host!() in ssl_options
    end

    test "ca_cert is ignored when ssl is disabled" do
      options = Config.amqp_consumer_options!()
      assert Keyword.get(options, :ssl_options) == nil
    end

    test "and server name indication is disabled" do
      Config.put_amqp_consumer_ssl_enabled(true)
      Config.put_amqp_consumer_ssl_disable_sni(true)

      Config.amqp_producer_options!()

      ssl_options =
        Config.amqp_producer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert server_name_indication: :disable in ssl_options
    end
  end

  describe "amqp producer options" do
    test "get default values when not set" do
      amqp_producer_options = Config.amqp_producer_options!()

      assert length(amqp_producer_options) == 5
      assert password: Config.amqp_consumer_password!() in amqp_producer_options
      assert username: Config.amqp_consumer_username!() in amqp_producer_options
      assert port: Config.amqp_consumer_port!() in amqp_producer_options
      assert host: Config.amqp_consumer_host!() in amqp_producer_options
      assert virtual_host: Config.amqp_consumer_virtual_host!() in amqp_producer_options

      assert Keyword.get(amqp_producer_options, :ssl_options) == nil

      # TODO remove asimmetry here
      assert Config.amqp_producer_options!() ++
               [channels: Config.amqp_consumer_channels_per_connection_number!()] ==
               Config.amqp_consumer_options!()
    end

    test "after setting its values" do
      Config.put_amqp_producer_password("password")
      Config.put_amqp_producer_username("username")
      Config.put_amqp_producer_port(12345)
      Config.put_amqp_producer_host("host")
      Config.put_amqp_producer_virtual_host("virtual_host")

      amqp_producer_options = Config.amqp_producer_options!()

      assert length(amqp_producer_options) == 5
      assert password: "password" in amqp_producer_options
      assert username: "username" in amqp_producer_options
      assert port: 12345 in amqp_producer_options
      assert host: "host" in amqp_producer_options
      assert virtual_host: "virtual_host" in amqp_producer_options
      assert Keyword.get(amqp_producer_options, :ssl_options) == nil
    end

    test "SSL is enabled for consumer and ca_cart is not set neither for producer nor for consumer" do
      Config.put_amqp_consumer_ssl_enabled(true)

      ssl_amqp_producer_options =
        Config.amqp_producer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert cacertfile: CAStore.file_path() in ssl_amqp_producer_options

      assert server_name_indication:
               Config.amqp_consumer_ssl_custom_sni!() in ssl_amqp_producer_options

      # TODO remove asimmetry here
      assert Config.amqp_producer_options!() ++
               [channels: Config.amqp_consumer_channels_per_connection_number!()] ==
               Config.amqp_consumer_options!()
    end

    test "SSL is enabled for consumer and its ca_cert is set" do
      ca_cert_path = "/the/path/to/ca_cert.pem"
      Config.put_amqp_consumer_ssl_enabled(true)
      Config.put_amqp_consumer_ssl_ca_file(ca_cert_path)

      ssl_amqp_producer_options =
        Config.amqp_producer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert cacertfile: ca_cert_path in ssl_amqp_producer_options

      assert server_name_indication:
               Config.amqp_consumer_ssl_custom_sni!() in ssl_amqp_producer_options

      # TODO remove asimmetry here
      assert Config.amqp_producer_options!() ++
               [channels: Config.amqp_consumer_channels_per_connection_number!()] ==
               Config.amqp_consumer_options!()
    end

    test "SSL is enabled and ca_cert is set for producer" do
      ca_cert_path = "/the/path/to/ca_cert.pem"
      Config.put_amqp_producer_ssl_enabled(true)
      Config.put_amqp_producer_ssl_ca_file(ca_cert_path)

      ssl_amqp_producer_options =
        Config.amqp_producer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert cacertfile: ca_cert_path in ssl_amqp_producer_options
    end

    test "ssl is enabled and server name indication is disabled for producer" do
      Config.put_amqp_producer_ssl_enabled(true)
      Config.put_amqp_producer_ssl_disable_sni(true)

      Config.amqp_producer_options!()

      ssl_options =
        Config.amqp_producer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert server_name_indication: :disable in ssl_options
    end
  end
end
