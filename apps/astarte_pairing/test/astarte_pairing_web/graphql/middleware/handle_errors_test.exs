#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.PairingWeb.GraphQL.Middleware.HandleErrorsTest do
  use ExUnit.Case, async: true

  alias Astarte.PairingWeb.GraphQL.Middleware.HandleErrors

  defp handle(errors) do
    %Absinthe.Resolution{errors: errors}
    |> HandleErrors.call([])
    |> Map.fetch!(:errors)
  end

  test "keeps the errors Absinthe can already render" do
    errors = ["a message", :not_found, [message: "keyword"], %{message: "map"}]

    assert handle(errors) == errors
  end

  test "turns a changeset into a validation error carrying its field errors" do
    changeset =
      {%{}, %{key_name: :string}}
      |> Ecto.Changeset.cast(%{}, [:key_name])
      |> Ecto.Changeset.validate_required(:key_name)

    assert handle([changeset]) == [
             %{message: "Validation failed", details: %{key_name: ["can't be blank"]}}
           ]
  end

  test "inspects any other error" do
    assert handle([{:unexpected_status, 500}]) == ["{:unexpected_status, 500}"]
  end
end
