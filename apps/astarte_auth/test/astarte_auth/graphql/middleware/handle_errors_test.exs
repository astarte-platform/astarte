#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.Auth.GraphQL.Middleware.HandleErrorsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Astarte.Auth.GraphQL.Middleware.HandleErrors

  defp handle(errors) do
    %Absinthe.Resolution{errors: errors}
    |> HandleErrors.call([])
    |> Map.fetch!(:errors)
  end

  test "turns a changeset into a validation error carrying its field errors" do
    changeset =
      {%{}, %{name: :string}}
      |> Ecto.Changeset.cast(%{name: "a"}, [:name])
      |> Ecto.Changeset.validate_length(:name, min: 2)

    assert handle([changeset]) == [
             %{
               message: "Validation failed",
               details: %{name: ["should be at least 2 character(s)"]}
             }
           ]
  end

  test "turns a cast error on an array field into a validation error" do
    changeset = Ecto.Changeset.cast({%{}, %{tags: {:array, :string}}}, %{tags: 1}, [:tags])

    assert handle([changeset]) == [
             %{message: "Validation failed", details: %{tags: ["is invalid"]}}
           ]
  end

  test "leaves an unknown placeholder in a changeset error message" do
    changeset =
      {%{}, %{name: :string}}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:name, "needs %{zzz_unknown}")

    assert handle([changeset]) == [
             %{message: "Validation failed", details: %{name: ["needs %{zzz_unknown}"]}}
           ]
  end

  test "keeps a string error" do
    assert handle(["a message"]) == ["a message"]
  end

  test "keeps an atom error" do
    assert handle([:not_found]) == [:not_found]
  end

  test "keeps a map error" do
    assert handle([%{message: "a message"}]) == [%{message: "a message"}]
  end

  test "logs any other error and reports it as an internal server error" do
    {errors, log} = with_log(fn -> handle([{:unexpected_status, 500}]) end)

    assert errors == ["Internal server error"]
    assert log =~ "Unexpected GraphQL resolver error"
  end
end
