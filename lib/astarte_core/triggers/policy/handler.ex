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

defmodule Astarte.Core.Triggers.Policy.Handler do
  @moduledoc """
  Defines the schema and changeset for trigger policy handlers.
  """

  use TypedEctoSchema
  import Ecto.Changeset
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword, as: ErrorKeywordProto
  alias Astarte.Core.Triggers.PolicyProtobuf.ErrorRange, as: ErrorRangeProto
  alias Astarte.Core.Triggers.PolicyProtobuf.Handler, as: HandlerProto

  @required_fields [
    :on,
    :strategy
  ]

  @error_keyword_string_to_atom %{
    "any_error" => :ANY_ERROR,
    "client_error" => :CLIENT_ERROR,
    "server_error" => :SERVER_ERROR
  }
  @error_keyword_atom_to_string %{
    :ANY_ERROR => "any_error",
    :CLIENT_ERROR => "client_error",
    :SERVER_ERROR => "server_error"
  }

  @strategy_string_to_atom %{
    "discard" => :DISCARD,
    "retry" => :RETRY
  }

  @strategy_atom_to_string %{
    :DISCARD => "discard",
    :RETRY => "retry"
  }

  @derive Jason.Encoder
  @primary_key false
  typed_embedded_schema do
    field :on, Policy.ErrorType
    field :strategy, :string, default: "discard"
  end

  def changeset(%Handler{} = handler, params \\ %{}) do
    handler
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:strategy, Map.keys(@strategy_string_to_atom))
  end

  def error_set(%Handler{on: error_type}) do
    values =
      case error_type do
        %Policy.ErrorKeyword{keyword: "any_error"} -> 400..599
        %Policy.ErrorKeyword{keyword: "client_error"} -> 400..499
        %Policy.ErrorKeyword{keyword: "server_error"} -> 500..599
        %Policy.ErrorRange{error_codes: errs} -> errs
        _ -> []
      end

    MapSet.new(values)
  end

  def includes_any?(%Handler{on: error_type}, errors) do
    Enum.any?(errors, &includes?(error_type, &1))
  end

  def includes?(%Handler{on: %Policy.ErrorKeyword{keyword: "any_error"}}, e)
      when e >= 400 and e <= 599,
      do: true

  def includes?(%Handler{on: %Policy.ErrorKeyword{keyword: "client_error"}}, e)
      when e >= 400 and e <= 499,
      do: true

  def includes?(%Handler{on: %Policy.ErrorKeyword{keyword: "server_error"}}, e)
      when e >= 500 and e <= 599,
      do: true

  def includes?(%Handler{on: %Policy.ErrorRange{error_codes: codes}}, e)
      when e >= 400 and e <= 599,
      do: Enum.member?(codes, e)

  def includes?(%Handler{}, _error), do: false

  def discards?(%Handler{strategy: "discard"}) do
    true
  end

  def discards?(%Handler{}) do
    false
  end

  def to_handler_proto(%Handler{} = handler) do
    %Handler{
      on: error_type,
      strategy: strategy
    } = handler

    %HandlerProto{
      strategy: Map.get(@strategy_string_to_atom, strategy),
      on: error_type_to_tagged_error_tuple(error_type)
    }
  end

  def from_handler_proto(%HandlerProto{} = handler_proto) do
    %HandlerProto{
      on: tagged_error_tuple,
      strategy: strategy
    } = handler_proto

    %Handler{
      on: tagged_error_tuple_to_error_type(tagged_error_tuple),
      strategy: Map.get(@strategy_atom_to_string, strategy)
    }
  end

  defp error_type_to_tagged_error_tuple(%Policy.ErrorKeyword{keyword: keyword}) do
    error_keyword = %ErrorKeywordProto{keyword: Map.get(@error_keyword_string_to_atom, keyword)}
    {:error_keyword, error_keyword}
  end

  defp error_type_to_tagged_error_tuple(%Policy.ErrorRange{error_codes: codes}) do
    error_range = %ErrorRangeProto{error_codes: codes}
    {:error_range, error_range}
  end

  defp tagged_error_tuple_to_error_type({_, %ErrorKeywordProto{keyword: keyword}}) do
    keyword_string = Map.get(@error_keyword_atom_to_string, keyword)
    %Policy.ErrorKeyword{keyword: keyword_string}
  end

  defp tagged_error_tuple_to_error_type({_, %ErrorRangeProto{error_codes: error_codes}}) do
    %Policy.ErrorRange{error_codes: error_codes}
  end
end
