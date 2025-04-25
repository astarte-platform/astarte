#
# This file is part of Astarte.
#
# Copyright 2020 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.Triggers.AMQPActionTest do
  use ExUnit.Case

  @moduletag :trigger_actions

  alias Astarte.RealmManagement.API.Triggers.AMQPAction
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Ecto.Changeset

  test "a valid AMQP action is accepted" do
    input = %{
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %AMQPAction{
              amqp_exchange: "astarte_events_test_custom_exchange",
              amqp_routing_key: "test_routing_key",
              amqp_message_persistent: true,
              amqp_message_expiration_ms: 5000,
              amqp_message_priority: 3
            }} == out
  end

  test "message priority is optional" do
    input = %{
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %AMQPAction{
              amqp_exchange: "astarte_events_test_custom_exchange",
              amqp_routing_key: "routing_key",
              amqp_message_persistent: true,
              amqp_message_expiration_ms: 5000
            }} == out
  end

  test "amqp_routing_key is mandatory" do
    input = %{
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_routing_key] == {"can't be blank", [validation: :required]}
  end

  test "an empty routing key is not accepted" do
    input = %{
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_routing_key] == {"can't be blank", [validation: :required]}
  end

  test "amqp_exchange must contain realm_name" do
    input = %{
      "amqp_exchange" => "astarte_events_other_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_exchange] == {"has invalid format", [{:validation, :format}]}
    assert length(errors) == 1
  end

  test "amqp_exchange must have a well known prefix" do
    input = %{
      "amqp_exchange" => "test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_exchange] == {"has invalid format", [{:validation, :format}]}
    assert length(errors) == 1
  end

  test "amqp_exchange is mandatory" do
    input = %{
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => false,
      "amqp_message_expiration_ms" => 100
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_exchange] == {"can't be blank", [validation: :required]}
    assert length(errors) == 1
  end

  test "amqp_message_priority must below 10" do
    input = %{
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => false,
      "amqp_message_expiration_ms" => 100,
      "amqp_message_priority" => 1000
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out

    assert errors[:amqp_message_priority] ==
             {"is invalid", [{:validation, :inclusion}, {:enum, 0..9}]}

    assert length(errors) == 1
  end

  test "amqp_static_headers must have only string values" do
    input = %{
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "test",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3,
      "amqp_static_headers" => %{"Foo" => 5}
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input, realm_name: "test")
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out

    assert errors[:amqp_static_headers] ==
             {"is invalid", [type: {:map, :string}, validation: :cast]}

    assert length(errors) == 1
  end

  test "headers over the max size are rejected" do
    value = String.duplicate("a", 2048)
    headers = Enum.into(1..40, %{}, &{Integer.to_string(&1), value})

    input = %{
      "amqp_exchange" => "astarte_events_test_exchange",
      "amqp_routing_key" => "key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_static_headers" => headers
    }

    changeset = AMQPAction.changeset(%AMQPAction{}, input, realm_name: "test")

    assert {"headers total size must be lower than 65536", _} =
             Keyword.get(changeset.errors, :amqp_static_headers)
  end

  test "recognizes atom keys for AMQP action" do
    action = %{amqp_exchange: "some_exchange"}
    input = %{name: "test", policy: "ok", action: action}

    updated = Trigger.move_action(input)
    assert Map.has_key?(updated, :amqp_action)
    assert updated[:amqp_action] == action
  end
end
