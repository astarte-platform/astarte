#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Triggers.Policy.ErrorKeyword do
  @moduledoc """
  This module provides generators for Astarte Trigger Policy ErrorKeyword.
  """
  alias Astarte.Core.Generators.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorKeyword

  use ExUnitProperties
  use Astarte.Generators.Utilities.ParamsGen

  @any_error "any_error"
  @client_error "client_error"
  @server_error "server_error"

  @doc """
  Returns the keyword representing "any_error" for the ErrorKeyword generator.
  """
  @spec any_error() :: String.t()
  def any_error, do: @any_error

  @doc """
  Returns the keyword representing "client_error" for the ErrorKeyword generator.
  """
  @spec client_error() :: String.t()
  def client_error, do: @client_error

  @doc """
  Returns the keyword representing "server_error" for the ErrorKeyword generator.
  """
  @spec server_error() :: String.t()
  def server_error, do: @server_error

  @doc """
  Returns the list of specific error keywords supported by the ErrorKeyword generator.
  """
  @spec other_errors() :: [String.t()]
  def other_errors, do: [client_error(), server_error()]

  @doc """
  Generates a valid Astarte Triggers Policy ErrorKeyword from scratch
  """
  @spec error_keyword(params :: keyword()) :: StreamData.t(ErrorKeyword.t())
  def error_keyword(params \\ []) do
    params gen all keyword <- keyword(), params: params do
      %ErrorKeyword{
        keyword: keyword
      }
    end
  end

  @doc """
  Convert this struct/stream to changes
  """
  @spec to_changes(ErrorKeyword.t()) :: StreamData.t(map())
  def to_changes(data) when not is_struct(data, StreamData),
    do: data |> constant() |> to_changes()

  @spec to_changes(StreamData.t(ErrorKeyword.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all %ErrorKeyword{keyword: keyword} <- gen do
      %{
        "keyword" => keyword
      }
    end
  end

  defp keyword, do: member_of([any_error() | other_errors()])
end
