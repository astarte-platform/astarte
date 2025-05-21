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

defmodule Astarte.RealmManagement.API.Fixtures.Trigger do
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
end
