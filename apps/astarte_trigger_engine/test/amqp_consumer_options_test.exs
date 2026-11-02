#
# This file is part of Astarte.
#
# Copyright 2020 - 2026 Clea Srl
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

defmodule Astarte.TriggerEngine.AMQPConsumerOptionsTest do
  alias Astarte.TriggerEngine.Config
  use ExUnit.Case, async: true
  use Mimic

  describe "amqp_consumer_options when ssl is enabled" do
    test "no ca_cert is set" do
      Mimic.stub(Config, :amqp_consumer_ssl_enabled!, fn -> true end)

      ssl_options =
        Config.amqp_consumer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert {:cacertfile, CAStore.file_path()} in ssl_options
    end

    test "ca_cert is set" do
      ca_cert_path = "/the/path/to/ca_cert.pem"
      Mimic.stub(Config, :amqp_consumer_ssl_enabled!, fn -> true end)
      Mimic.stub(Config, :amqp_consumer_ssl_ca_file!, fn -> ca_cert_path end)

      ssl_options =
        Config.amqp_consumer_options!()
        |> Keyword.fetch!(:ssl_options)

      assert {:cacertfile, ca_cert_path} in ssl_options
    end
  end

  test "server name indication is disabled" do
    Mimic.stub(Config, :amqp_consumer_ssl_enabled!, fn -> true end)
    Mimic.stub(Config, :amqp_consumer_ssl_disable_sni!, fn -> true end)

    ssl_options =
      Config.amqp_consumer_options!()
      |> Keyword.fetch!(:ssl_options)

    assert {:server_name_indication, :disable} in ssl_options
  end

  test "server name indication is enabled" do
    Mimic.stub(Config, :amqp_consumer_ssl_enabled!, fn -> true end)
    Mimic.stub(Config, :amqp_consumer_ssl_disable_sni!, fn -> false end)

    ssl_options =
      Config.amqp_consumer_options!()
      |> Keyword.fetch!(:ssl_options)

    sni = to_charlist(Config.amqp_consumer_host!())
    assert {:server_name_indication, sni} in ssl_options
  end

  test "ca_cert is ignored when ssl is disabled" do
    options = Config.amqp_consumer_options!()
    assert Keyword.get(options, :ssl_options) == nil
  end
end
