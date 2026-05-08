#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind srl
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

defmodule Astarte.Core.Triggers.PolicyTest do
  use ExUnit.Case
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword, as: ErrorKeywordProto
  alias Astarte.Core.Triggers.PolicyProtobuf.ErrorRange, as: ErrorRangeProto
  alias Astarte.Core.Triggers.PolicyProtobuf.Handler, as: HandlerProto
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto

  @a_policy """
    {
      "name": "somename",
      "error_handlers": [
        {
          "on" : "any_error",
          "strategy": "retry"
        }
      ],
      "maximum_capacity": 300,
      "retry_times": 10,
      "event_ttl": 10
    }
  """

  test "valid policy" do
    params = %{
      name: "pippo",
      maximum_capacity: 100,
      error_handlers: [
        %{on: "any_error", strategy: "discard"}
      ]
    }

    assert %Ecto.Changeset{valid?: true} = Policy.changeset(%Policy{}, params)
  end

  describe "policy name validation" do
    test "valid policy_name with punctuation" do
      params = %{
        name: "org.astarte-platform.PolicyName",
        error_handlers: [
          %{on: "any_error", strategy: "discard"}
        ],
        maximum_capacity: 300
      }

      assert %Ecto.Changeset{valid?: true} = Policy.changeset(%Policy{}, params)
    end

    test "invalid policy name starting with @" do
      params = %{
        name: "@org.astarte-platform.PolicyName",
        error_handlers: [
          %{on: "any_error", strategy: "discard"}
        ],
        maximum_capacity: 300
      }

      assert %Ecto.Changeset{valid?: false, errors: [name: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "long policy name fails" do
      params = %{
        name: Stream.cycle(["a"]) |> Enum.take(129),
        error_handlers: [
          %{on: "any_error", strategy: "discard"}
        ],
        maximum_capacity: 300
      }

      assert %Ecto.Changeset{valid?: false, errors: [name: _]} =
               Policy.changeset(%Policy{}, params)
    end
  end

  describe "policy attributes combination" do
    test "invalid policy no handler" do
      params = %{
        name: "pippo",
        maximum_capacity: 100
      }

      assert %Ecto.Changeset{valid?: false, errors: [error_handlers: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "invalid policy retry and no retry_times " do
      params = %{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %{on: "any_error", strategy: "retry"}
        ]
      }

      assert %Ecto.Changeset{valid?: false, errors: [retry_times: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "invalid policy overlapping keyword handlers" do
      params = %{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %{on: "any_error", strategy: "discard"},
          %{on: "server_error", strategy: "discard"}
        ]
      }

      assert %Ecto.Changeset{valid?: false, errors: [error_handlers: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "invalid policy overlapping range handlers" do
      params = %{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %{on: [401, 402, 403, 404], strategy: "discard"},
          %{on: [404, 500], strategy: "discard"}
        ]
      }

      assert %Ecto.Changeset{valid?: false, errors: [error_handlers: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "invalid policy overlapping keyword and range handlers" do
      params = %{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %{on: "client_error", strategy: "discard"},
          %{on: [404, 500], strategy: "discard"}
        ]
      }

      assert %Ecto.Changeset{valid?: false, errors: [error_handlers: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "invalid policy discards with retry_times" do
      params = %{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %{on: "any_error", strategy: "discard"}
        ],
        retry_times: 10
      }

      assert %Ecto.Changeset{valid?: false, errors: [retry_times: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "invalid policy prefetch_count out of range" do
      params = %{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %{on: "any_error", strategy: "discard"}
        ],
        prefetch_count: 0
      }

      assert %Ecto.Changeset{valid?: false, errors: [prefetch_count: _]} =
               Policy.changeset(%Policy{}, params)
    end

    test "valid policy discard and retry" do
      params = %{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %{on: "client_error", strategy: "retry"},
          %{on: "server_error", strategy: "discard"}
        ],
        retry_times: 10
      }

      assert %Ecto.Changeset{valid?: true} = Policy.changeset(%Policy{}, params)
    end
  end

  describe "policy protobuf roundtrip" do
    test "when prefetch_count is set" do
      policy = %Policy{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %Handler{on: %ErrorKeyword{keyword: "client_error"}, strategy: "retry"},
          %Handler{on: %ErrorRange{error_codes: [500, 501, 503]}, strategy: "discard"}
        ],
        retry_times: 10,
        prefetch_count: 2
      }

      policy_proto = Policy.to_policy_proto(policy)

      assert %PolicyProto{
               name: "pippo",
               maximum_capacity: 100,
               retry_times: 10,
               event_ttl: 0,
               prefetch_count: 2,
               error_handlers: error_handlers
             } = policy_proto

      assert [
               %HandlerProto{
                 strategy: :RETRY,
                 on: tagged_error_keyword
               },
               %HandlerProto{
                 strategy: :DISCARD,
                 on: tagged_error_range
               }
             ] = error_handlers

      assert {:error_keyword, %ErrorKeywordProto{keyword: :CLIENT_ERROR}} = tagged_error_keyword

      assert {:error_range, %ErrorRangeProto{error_codes: [500, 501, 503]}} = tagged_error_range

      assert policy == Policy.from_policy_proto!(policy_proto)
    end

    test "when prefetch_count is not set" do
      policy = %Policy{
        name: "pippo",
        maximum_capacity: 100,
        error_handlers: [
          %Handler{on: %ErrorKeyword{keyword: "client_error"}, strategy: "retry"},
          %Handler{on: %ErrorRange{error_codes: [500, 501, 503]}, strategy: "discard"}
        ],
        retry_times: 10
      }

      policy_proto = Policy.to_policy_proto(policy)

      assert %PolicyProto{
               name: "pippo",
               maximum_capacity: 100,
               retry_times: 10,
               event_ttl: 0,
               error_handlers: error_handlers
             } = policy_proto

      assert [
               %HandlerProto{
                 strategy: :RETRY,
                 on: tagged_error_keyword
               },
               %HandlerProto{
                 strategy: :DISCARD,
                 on: tagged_error_range
               }
             ] = error_handlers

      assert {:error_keyword, %ErrorKeywordProto{keyword: :CLIENT_ERROR}} = tagged_error_keyword

      assert {:error_range, %ErrorRangeProto{error_codes: [500, 501, 503]}} = tagged_error_range

      assert policy == Policy.from_policy_proto!(policy_proto)
    end
  end

  test "JSON encode" do
    policy = %Policy{
      name: "somename",
      error_handlers: [
        %Handler{
          on: %ErrorKeyword{keyword: "any_error"},
          strategy: "retry"
        }
      ],
      maximum_capacity: 300,
      retry_times: 10,
      prefetch_count: 1
    }

    assert Jason.decode!(Jason.encode!(policy)) ==
             %{
               "name" => "somename",
               "error_handlers" => [
                 %{
                   "on" => %{"keyword" => "any_error"},
                   "strategy" => "retry"
                 }
               ],
               "maximum_capacity" => 300,
               "retry_times" => 10,
               "event_ttl" => nil,
               "prefetch_count" => 1
             }
  end

  test "JSON decode" do
    {:ok, params} = Jason.decode(@a_policy)

    {:ok, _policy} =
      Policy.changeset(%Policy{}, params)
      |> Ecto.Changeset.apply_action(:insert)
  end
end
