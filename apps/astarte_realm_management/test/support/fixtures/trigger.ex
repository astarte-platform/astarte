#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Fixtures.Trigger do
  alias Astarte.Core.Triggers.Trigger

  @valid_attrs %{
    "name" => "test_trigger",
    "simple_triggers" => [
      %{
        "type" => "device_trigger",
        "device_id" => "*",
        "on" => "device_connected",
        "interface_major" => 0
      }
    ],
    "action" => %{
      "http_url" => "http://www.example.com",
      "http_method" => "delete",
      "ignore_ssl_errors" => false
    }
  }
  @invalid_attrs %{
    "name" => 5,
    "action" => %{
      "http_url" => "http://www.example.com",
      "http_method" => "delete",
      "ignore_ssl_errors" => false
    }
  }
  @invalid_http_method %{
    "name" => "invalid_test_trigger",
    "action" => %{
      "http_url" => "http://www.example.com",
      "http_method" => "not_existing_method",
      "ignore_ssl_errors" => false
    }
  }
  def valid_trigger_attrs(attrs \\ %{}), do: Enum.into(attrs, @valid_attrs)
  def invalid_trigger_attrs(attrs \\ %{}), do: Enum.into(attrs, @invalid_attrs)
  def invalid_http_method, do: @invalid_http_method

  def triggers(name_gen) do
    default_action_triggers(name_gen) ++
      mustache_triggers(name_gen) ++ triggers_with_static_headers(name_gen)
  end

  def default_action_triggers(name_gen) do
    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "put",
      "ignore_ssl_errors": true
    }
    """

    [
      %Trigger{
        trigger_uuid: <<5, 94, 105, 231, 207, 92, 65, 80, 150, 231, 248, 187, 116, 95, 143, 49>>,
        name: name_gen |> Enum.take(1) |> Enum.at(0),
        action: action
      }
    ]
  end

  def mustache_triggers(name_gen) do
    action_1 = """
    {
      "http_post_url": "http://hello.world.ai",
      "ignore_ssl_errors": true,
      "template": "",
      "template_type": "mustache"
    }
    """

    action_2 = """
    {
      "http_post_url": "http://hello.world.ai",
      "template": "{{new_value}}",
      "template_type": "mustache"
    }
    """

    [
      %Trigger{
        trigger_uuid: <<150, 67, 77, 67, 99, 180, 73, 104, 191, 225, 11, 143, 30, 171, 126, 0>>,
        name: name_gen |> Enum.take(1) |> Enum.at(0),
        action: action_1
      },
      %Trigger{
        trigger_uuid: <<253, 52, 226, 246, 41, 25, 73, 20, 175, 162, 25, 77, 242, 196, 195, 249>>,
        name: name_gen |> Enum.take(1) |> Enum.at(0),
        action: action_2
      }
    ]
  end

  def triggers_with_static_headers(name_gen) do
    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "put",
      "http_static_headers": {
        "my-header": "its-value",
        "other-header": "other-value"
      }
    }
    """

    [
      %Trigger{
        trigger_uuid: <<62, 82, 54, 254, 110, 68, 64, 127, 182, 74, 244, 238, 169, 16, 27, 183>>,
        name: name_gen |> Enum.take(1) |> Enum.at(0),
        action: action
      }
    ]
  end

  def invalid_triggers do
    action_1 = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "non_existing_method"
    }
    """

    action_2 = """
    {
      "http_url": "http://hello.world.ai"
    }
    """

    [
      %Trigger{
        trigger_uuid:
          <<235, 114, 113, 198, 119, 0, 68, 19, 186, 188, 63, 239, 255, 91, 168, 207>>,
        name: "invalid_trigger_1",
        action: action_1
      },
      %Trigger{
        trigger_uuid:
          <<190, 153, 181, 250, 46, 6, 74, 38, 187, 164, 146, 210, 16, 220, 210, 143>>,
        name: "invalid_trigger_2",
        action: action_2
      }
    ]
  end

  def triggers_not_installed(name_gen) do
    action_1 = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "non_existing_method"
    }
    """

    action_2 = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "put",
      "ignore_ssl_errors": true
    }
    """

    [
      %Trigger{
        trigger_uuid: <<225, 27, 36, 192, 219, 113, 72, 46, 157, 10, 58, 133, 169, 72, 195, 230>>,
        name: name_gen |> Enum.take(1) |> Enum.at(0),
        action: action_1
      },
      %Trigger{
        trigger_uuid: <<19, 49, 163, 43, 16, 233, 74, 195, 166, 63, 108, 32, 189, 16, 145, 135>>,
        name: name_gen |> Enum.take(1) |> Enum.at(0),
        action: action_2
      }
    ]
  end

  def all_triggers(name_gen) do
    triggers(name_gen) ++ invalid_triggers()
  end
end
