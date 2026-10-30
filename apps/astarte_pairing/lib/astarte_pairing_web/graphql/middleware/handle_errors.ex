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

defmodule Astarte.PairingWeb.GraphQL.Middleware.HandleErrors do
  @moduledoc """
  Translates resolver errors into GraphQL errors, like
  `Astarte.PairingWeb.FallbackController` does for REST.
  """

  @behaviour Absinthe.Middleware

  alias Astarte.PairingWeb.ChangesetView

  @impl Absinthe.Middleware
  def call(resolution, _opts) do
    %{resolution | errors: Enum.map(resolution.errors, &translate_error/1)}
  end

  defp translate_error(%Ecto.Changeset{} = changeset) do
    %{message: "Validation failed", details: ChangesetView.translate_errors(changeset)}
  end

  defp translate_error(error) when is_binary(error) or is_atom(error), do: error
  defp translate_error(error) when is_list(error) or is_non_struct_map(error), do: error
  defp translate_error(error), do: inspect(error)
end
