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

defmodule Astarte.Secrets.Key.Revision do
  @moduledoc """
  Single key revision for a Vault key
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Astarte.Secrets.Core
  alias Ecto.Changeset

  @asymmetric_key_algorithms Core.asymmetric_key_algorithms()

  @primary_key false
  typed_embedded_schema do
    field :key_algorithm, Ecto.Enum, values: Core.key_algorithm_enum()
    field :index, :integer
    field :public_key, :string
  end

  @spec changeset(t(), Core.key_algorithm(), integer(), term()) :: Changeset.t()
  def changeset(revision, key_algorithm, index, params = %{})
      when key_algorithm in @asymmetric_key_algorithms do
    attrs = %{key_algorithm: key_algorithm, index: index}

    revision
    |> cast(params, [:public_key])
    |> validate_required([:public_key])
    |> change(attrs)
  end

  def changeset(revision, key_algorithm, _index, params)
      when key_algorithm in @asymmetric_key_algorithms do
    revision
    |> change()
    |> add_error(:key_algorithm, "unknown parameter format for asymmetric key algorithm",
      params: params
    )
  end

  def changeset(revision, key_algorithm, _index, _params) do
    revision
    |> change()
    |> add_error(:key_algorithm, "is not supported", key_algorithm: key_algorithm)
  end
end
