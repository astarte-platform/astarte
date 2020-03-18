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

    Config.reload_amqp_producer_password()
    Config.reload_amqp_producer_username()
    Config.reload_amqp_producer_port()
    Config.reload_amqp_producer_host()
    Config.reload_amqp_producer_virtual_host()
  end

  setup do
    on_exit(&reset_to_defaults/0)
  end

  test "amqp producer options get default values when not set" do
    amqp_producer_options = Config.amqp_producer_options!()

    assert length(amqp_producer_options) == 5
    assert password: Config.amqp_consumer_password!() in amqp_producer_options
    assert username: Config.amqp_consumer_username!() in amqp_producer_options
    assert port: Config.amqp_consumer_port!() in amqp_producer_options
    assert host: Config.amqp_consumer_host!() in amqp_producer_options
    assert virtual_host: Config.amqp_consumer_virtual_host!() in amqp_producer_options

    assert Config.amqp_producer_options!() == Config.amqp_consumer_options!()
  end

  test "amqp producer options after setting its values" do
    Config.put_amqp_producer_password("passwors")
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
  end
end
