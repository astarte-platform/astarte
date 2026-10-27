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
  alias Astarte.Secrets.Key.Revision

  @primary_key false
  typed_embedded_schema do
    field :name, :string
    field :namespace, :string
    field :alg, Ecto.Enum, values: Core.key_algorithm_enum()
    embeds_many :revisions, Revision
    field :public_pem, :string
  end

  @doc """
  Convert the result from OpenBao's API into `t()`
  """
  @spec parse(String.t(), String.t(), map()) :: {:ok, t()} | {:error, term()}
  def parse(key_name, namespace, data) do
    revisions =
      Map.new(data["keys"], fn {revision, params} ->
        params = %{params: params, revision: revision}
        {revision, params}
      end)

    params = %{
      "namespace" => namespace,
      "name" => key_name,
      "alg" => data["type"],
      "revisions" => revisions
    }

    changeset = changeset(%Key{}, params)
    apply_action(changeset, :insert)
  end

  def changeset(key, params) do
    key
    |> cast(params, [:namespace, :name, :alg])
    |> validate_required([:namespace, :name, :alg])
    |> cast_revisions(:revisions)
    |> cast_public_pem()
  end

  defp cast_revisions(changeset, key) when changeset.valid? do
    # SAFETY: `:alg` is required and the changeset is valid
    alg = fetch_field!(changeset, :alg)
    cast_fun = fn revision, params -> Revision.changeset(revision, alg, params) end

    changeset
    |> cast_embed(key, required: true, with: cast_fun)
  end

  defp cast_revisions(changeset, _key), do: changeset

  defp cast_public_pem(changeset) do
    with true <- changeset.valid?,
         true <- get_field(changeset, :alg) in Core.asymmetric_key_algorithms(),
         {:ok, revisions} <- fetch_change(changeset, :revisions),
         # SAFETY: we always have at least one revision otherwise the changeset would be invalid,
         # because we cast :revisions with `required: true`.
         # Revisions are sorted by key, so the last one is the latest revision
         latest_revision = List.last(revisions),
         true <- latest_revision.valid? do
      # SAFETY: public_key is a required field and the revision is valid
      public_pem = fetch_field!(latest_revision, :public_key)
      params = %{public_pem: public_pem}

      changeset
      |> change(params)
    else
      _ -> changeset
    end
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

  def encode(_key) do
    raise "`Astarte.Secrets.Key.encode/1`: Not yet implemented"
  end
end
