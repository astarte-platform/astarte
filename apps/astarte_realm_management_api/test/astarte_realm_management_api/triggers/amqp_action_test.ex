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

defmodule Astarte.RealmManagement.API.Triggers.AMQPActionTest do
  use ExUnit.Case
  alias Astarte.RealmManagement.API.Triggers.AMQPAction
  alias Ecto.Changeset

  test "a valid AMQP action is accepted" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %AMQPAction{
              realm_name: "test",
              amqp_exchange: "astarte_events_test_custom_exchange",
              amqp_routing_key: "test_routing_key",
              amqp_message_persistent: true,
              amqp_message_expiration_ms: 5000,
              amqp_message_priority: 3
            }} == out
  end

  test "message priority is optional" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %AMQPAction{
              realm_name: "test",
              amqp_exchange: "astarte_events_test_custom_exchange",
              amqp_routing_key: "routing_key",
              amqp_message_persistent: true,
              amqp_message_expiration_ms: 5000
            }} == out
  end

  test "an empty routing key is accepted" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %AMQPAction{
              realm_name: "test",
              amqp_exchange: "astarte_events_test_custom_exchange",
              amqp_routing_key: "",
              amqp_message_persistent: true,
              amqp_message_expiration_ms: 5000,
              amqp_message_priority: 3
            }} == out
  end

  test "amqp_exchange must contain realm_name" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_other_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_exchange] == {"has invalid format", [{:validation, :format}]}
    assert length(errors) == 1
  end

  test "amqp_exchange must have a well known prefix" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_exchange] == {"has invalid format", [{:validation, :format}]}
    assert length(errors) == 1
  end

  test "amqp_exchange is mandatory" do
    input = %{
      "realm_name" => "test",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => false,
      "amqp_message_expiration_ms" => 100
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:amqp_exchange] == {"can't be blank", [validation: :required]}
    assert length(errors) == 1
  end

  test "amqp_message_priority must below 10" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => false,
      "amqp_message_expiration_ms" => 100,
      "amqp_message_priority" => 1000
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out

    assert errors[:amqp_message_priority] ==
             {"is invalid", [{:validation, :inclusion}, {:enum, 0..9}]}

    assert length(errors) == 1
  end

  test "a valid AMQPAction can be encoded to JSON" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => true,
      "amqp_message_expiration_ms" => 5000,
      "amqp_message_priority" => 3
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok, action} = out

    jason_out_map =
      action
      |> Jason.encode!()
      |> Jason.decode!()

    assert jason_out_map == %{
             "amqp_exchange" => "astarte_events_test_custom_exchange",
             "amqp_routing_key" => "test_routing_key",
             "amqp_message_persistent" => true,
             "amqp_message_expiration_ms" => 5000,
             "amqp_message_priority" => 3
           }
  end

  test "not set message priority is omitted" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "test_routing_key",
      "amqp_message_persistent" => false,
      "amqp_message_expiration_ms" => 5000
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok, action} = out

    jason_out_map =
      action
      |> Jason.encode!()
      |> Jason.decode!()

    assert jason_out_map == %{
             "amqp_exchange" => "astarte_events_test_custom_exchange",
             "amqp_routing_key" => "test_routing_key",
             "amqp_message_persistent" => false,
             "amqp_message_expiration_ms" => 5000
           }
  end

  test "empty routing key is encoded to empty string" do
    input = %{
      "realm_name" => "test",
      "amqp_exchange" => "astarte_events_test_custom_exchange",
      "amqp_routing_key" => "",
      "amqp_message_persistent" => false,
      "amqp_message_expiration_ms" => 5000
    }

    out =
      %AMQPAction{}
      |> AMQPAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok, action} = out

    jason_out_map =
      action
      |> Jason.encode!()
      |> Jason.decode!()

    assert jason_out_map == %{
             "amqp_exchange" => "astarte_events_test_custom_exchange",
             "amqp_routing_key" => "",
             "amqp_message_persistent" => false,
             "amqp_message_expiration_ms" => 5000
           }
  end
end
