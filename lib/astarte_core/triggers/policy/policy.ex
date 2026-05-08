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

defmodule Astarte.Core.Triggers.Policy do
  @moduledoc """
  Defines the schema and changeset for Astarte trigger policies.
  """

  use TypedEctoSchema
  import Ecto.Changeset

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto

  @policy_name_regex ~r/^(?!@).+$/

  @required_fields [
    :name,
    :maximum_capacity
  ]

  @permitted_fields [
    :name,
    :maximum_capacity,
    :retry_times,
    :event_ttl,
    :prefetch_count
  ]

  @derive Jason.Encoder
  @primary_key false
  typed_embedded_schema do
    field :name
    field :maximum_capacity, :integer
    field :retry_times, :integer
    field :event_ttl, :integer
    field :prefetch_count, :integer
    embeds_many :error_handlers, Policy.Handler
  end

  def changeset(%Policy{} = policy, params \\ %{}) do
    policy
    |> cast(params, @permitted_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, max: 128)
    |> validate_format(:name, @policy_name_regex)
    |> validate_inclusion(:retry_times, 1..100)
    |> validate_inclusion(:event_ttl, 1..86_400)
    |> validate_inclusion(:maximum_capacity, 1..1_000_000)
    |> validate_inclusion(:prefetch_count, 1..300)
    |> cast_embed(:error_handlers, with: &Handler.changeset/2, required: true)
    |> validate_length(:error_handlers, min: 1, max: 200)
    |> validate_all_handlers_on_different_errors()
    |> validate_retry_times_compatible()
  end

  def valid_name?(name) do
    String.match?(name, @policy_name_regex)
  end

  defp validate_all_handlers_on_different_errors(changeset) do
    handlers = get_field(changeset, :error_handlers, [])

    if disjoint_errors?(handlers) do
      changeset
    else
      add_error(changeset, :error_handlers, "must all handle distinct errors.")
    end
  end

  defp disjoint_errors?(handlers) do
    {_, disjoint?} =
      Enum.map(handlers, &Handler.error_set/1)
      |> Enum.reduce_while({MapSet.new(), true}, fn error_set, {error_set_acc, _disjoint?} ->
        if MapSet.disjoint?(error_set, error_set_acc) do
          {:cont, {MapSet.union(error_set, error_set_acc), true}}
        else
          {:halt, {nil, false}}
        end
      end)

    disjoint?
  end

  defp validate_retry_times_compatible(changeset) do
    handlers = get_field(changeset, :error_handlers, [])
    retry_times = get_field(changeset, :retry_times)
    all_discards = Enum.all?(handlers, &Handler.discards?/1)

    cond do
      all_discards and retry_times != nil ->
        add_error(changeset, :retry_times, "must not be set if all errors are discarded.")

      not all_discards and retry_times == nil ->
        add_error(changeset, :retry_times, "must be set if some events are to be retried.")

      true ->
        changeset
    end
  end

  @doc """
  Creates a `Policy` from a `PolicyProto`.
  Returns `{:ok, %Policy{}}` on success, `{:error, :invalid_policy_data}` on failure
  """
  def from_policy_proto(%PolicyProto{} = policy_proto) do
    case policy_proto do
      %PolicyProto{
        name: name,
        maximum_capacity: maximum_capacity,
        retry_times: retry_times,
        event_ttl: event_ttl,
        prefetch_count: prefetch_count,
        error_handlers: error_handlers
      } ->
        event_ttl = if event_ttl != 0, do: event_ttl, else: nil

        {:ok,
         %Policy{
           name: name,
           error_handlers: Enum.map(error_handlers, &Handler.from_handler_proto/1),
           maximum_capacity: maximum_capacity,
           retry_times: retry_times,
           event_ttl: event_ttl,
           prefetch_count: prefetch_count
         }}

      _ ->
        {:error, :invalid_policy_data}
    end
  end

  @doc """
  Creates a `Policy` from a `PolicyProto`.

  Returns the `%Policy{}` on success,
  raises on failure
  """
  def from_policy_proto!(policy_proto) do
    case from_policy_proto(policy_proto) do
      {:ok, policy} -> policy
      _ -> raise ArgumentError
    end
  end

  @doc """
  Creates a `PolicyProto` from a `Policy`.

  It is assumed that the `Policy` is valid and constructed using `Policy.changeset`

  Returns a `%PolicyProto{}`
  """
  def to_policy_proto(%Policy{} = policy) do
    %Policy{
      name: name,
      error_handlers: error_handlers,
      maximum_capacity: maximum_capacity,
      retry_times: retry_times,
      event_ttl: event_ttl,
      prefetch_count: prefetch_count
    } = policy

    %PolicyProto{
      name: name,
      maximum_capacity: maximum_capacity,
      retry_times: retry_times,
      event_ttl: event_ttl || 0,
      prefetch_count: prefetch_count,
      error_handlers: Enum.map(error_handlers, &Handler.to_handler_proto/1)
    }
  end
end
