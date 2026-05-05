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
end
