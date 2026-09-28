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

defmodule Astarte.Core.Triggers.Policy.HandlerTest do
  use ExUnit.Case
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler

  test "valid keyword handler" do
    params = %{
      "on" => "any_error",
      "strategy" => "discard"
    }

    assert %Ecto.Changeset{valid?: true} = Handler.changeset(%Handler{}, params)
  end

  test "valid Http error codes handler" do
    params = %{
      "on" => [400, 401, 502],
      "strategy" => "discard"
    }

    assert %Ecto.Changeset{valid?: true} = Handler.changeset(%Handler{}, params)
  end

  test "invalid keyword handler fails" do
    params = %{
      "on" => "invalid_error",
      "strategy" => "discard"
    }

    assert %Ecto.Changeset{valid?: false, errors: [on: _]} = Handler.changeset(%Handler{}, params)
  end

  test "empty http error codes handler fails" do
    params = %{
      "on" => [],
      "strategy" => "discard"
    }

    assert %Ecto.Changeset{valid?: false, errors: [on: _]} = Handler.changeset(%Handler{}, params)
  end

  test "invalid (< 400) http error codes handler fails" do
    params = %{
      "on" => [399],
      "strategy" => "discard"
    }

    assert %Ecto.Changeset{valid?: false, errors: [on: _]} = Handler.changeset(%Handler{}, params)
  end

  test "invalid (> 599) http error codes handler fails" do
    params = %{
      "on" => [600],
      "strategy" => "discard"
    }

    assert %Ecto.Changeset{valid?: false, errors: [on: _]} = Handler.changeset(%Handler{}, params)
  end

  test "invalid strategy handler fails" do
    params = %{
      "on" => "any_error",
      "strategy" => "none"
    }

    assert %Ecto.Changeset{valid?: false, errors: [strategy: _]} =
             Handler.changeset(%Handler{}, params)
  end

  test "error_set/1 covers all keyword and range branches" do
    assert MapSet.member?(
             Handler.error_set(%Handler{
               on: %Policy.ErrorKeyword{keyword: "any_error"},
               strategy: "discard"
             }),
             500
           )

    assert MapSet.member?(
             Handler.error_set(%Handler{
               on: %Policy.ErrorKeyword{keyword: "client_error"},
               strategy: "discard"
             }),
             404
           )

    assert MapSet.member?(
             Handler.error_set(%Handler{
               on: %Policy.ErrorKeyword{keyword: "server_error"},
               strategy: "discard"
             }),
             503
           )

    assert MapSet.member?(
             Handler.error_set(%Handler{
               on: %Policy.ErrorRange{error_codes: [404]},
               strategy: "discard"
             }),
             404
           )

    assert MapSet.equal?(Handler.error_set(%Handler{on: nil, strategy: "discard"}), MapSet.new())
  end

  test "discards?/1 returns true for discard, false for retry" do
    assert Handler.discards?(%Handler{
             on: %Policy.ErrorKeyword{keyword: "any_error"},
             strategy: "discard"
           })

    refute Handler.discards?(%Handler{
             on: %Policy.ErrorKeyword{keyword: "any_error"},
             strategy: "retry"
           })
  end

  test "to_handler_proto/from_handler_proto roundtrip covers keyword and range" do
    keyword_handler = %Handler{
      on: %Policy.ErrorKeyword{keyword: "server_error"},
      strategy: "retry"
    }

    assert keyword_handler ==
             keyword_handler |> Handler.to_handler_proto() |> Handler.from_handler_proto()

    range_handler = %Handler{on: %Policy.ErrorRange{error_codes: [400, 500]}, strategy: "discard"}

    assert range_handler ==
             range_handler |> Handler.to_handler_proto() |> Handler.from_handler_proto()
  end
end
