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

defmodule Astarte.AppEngine.API.RoomsAMQPOptionsTest do
  alias Astarte.AppEngine.API.Config
  use ExUnit.Case

  describe "amqp_options when ssl is enabled" do
    test "no ca_cert is set" do
      Config.put_rooms_amqp_client_ssl_enabled(true)

      ssl_options =
        Config.rooms_amqp_options!()
        |> Keyword.fetch!(:ssl_options)

      assert cacertfile: CAStore.file_path() in ssl_options

      Config.reload_rooms_amqp_client_ssl_enabled()
    end

    test "server name indication is disabled" do
      Config.put_rooms_amqp_client_ssl_enabled(true)
      Config.put_rooms_amqp_client_ssl_disable_sni(true)

      ssl_options =
        Config.rooms_amqp_options!()
        |> Keyword.fetch!(:ssl_options)

      assert server_name_indication: :disable in ssl_options

      Config.reload_rooms_amqp_client_ssl_enabled()
      Config.reload_rooms_amqp_client_ssl_disable_sni()
    end

    test "server name indication is enabled" do
      Config.put_rooms_amqp_client_ssl_enabled(true)
      Config.put_rooms_amqp_client_ssl_disable_sni(true)

      ssl_options =
        Config.rooms_amqp_options!()
        |> Keyword.fetch!(:ssl_options)

      assert server_name_indication: Config.rooms_amqp_client_host!() in ssl_options

      Config.reload_rooms_amqp_client_ssl_enabled()
      Config.reload_rooms_amqp_client_ssl_disable_sni()
    end

    test "ca_cert is set" do
      ca_cert_path = "/the/path/to/ca_cert.pem"
      Config.put_rooms_amqp_client_ssl_enabled(true)
      Config.put_rooms_amqp_client_ssl_ca_file(ca_cert_path)

      ssl_options =
        Config.rooms_amqp_options!()
        |> Keyword.fetch!(:ssl_options)

      assert cacertfile: ca_cert_path in ssl_options

      Config.reload_rooms_amqp_client_ssl_enabled()
      Config.reload_rooms_amqp_client_ssl_ca_file()
    end
  end

  test "ca_cert is ignored when ssl is disabled" do
    Config.put_rooms_amqp_client_ssl_enabled(false)
    options = Config.rooms_amqp_options!()

    assert Keyword.get(options, :ssl_options) == nil
    Config.reload_rooms_amqp_client_ssl_enabled()
  end
end
