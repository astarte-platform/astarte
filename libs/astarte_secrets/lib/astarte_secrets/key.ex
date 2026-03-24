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

defmodule Astarte.Secrets.Key do
  @moduledoc """
  `COSE.Keys.Key` implementation for OpenBao keys.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Astarte.Secrets.Core
  alias Astarte.Secrets.Key

  @primary_key false
  typed_embedded_schema do
    field :name, :string
    field :namespace, :string
    field :alg, Ecto.Enum, values: Core.key_algorithm_enum()
    field :public_pem, :string
  end

  @doc """
  Convert the result from OpenBao's API into `t()`
  """
  @spec parse(String.t(), String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def parse(key_name, namespace, response_body) do
    with {:ok, data} <- Core.parse_json_data(response_body) do
      params = %{
        "namespace" => namespace,
        "name" => key_name,
        "alg" => data["type"],
        "public_pem" => get_in(data, ["keys", "1", "public_key"])
      }

      changeset = changeset(%Key{}, params)
      apply_action(changeset, :insert)
    end
  end

  def changeset(key, params) do
    key
    |> cast(params, [:namespace, :name, :alg, :public_pem])
  end
end

defimpl COSE.Keys.Key, for: Astarte.Secrets.Key do
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  def sign(key, digest_type, to_be_signed) do
    %Key{name: name, namespace: namespace, alg: algorithm} = key
    opts = [namespace: namespace]

    with :error <- Secrets.sign(name, to_be_signed, algorithm, digest_type, opts) do
      {:error, :signature_error}
    end
  end

  def verify(_key, _digest_type, _to_be_verified, _signature) do
    raise "`Astarte.Secrets.Key.verify/4`: Not yet implemented"
  end
end
