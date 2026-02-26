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

defmodule Astarte.Pairing.FDO.Types.Error do
  use TypedStruct

  alias Astarte.Pairing.FDO.Types.Error

  typedstruct do
    field :error_code, non_neg_integer()
    field :previous_message_id, non_neg_integer()
    field :error_message, String.t()
    field :timestamp, nil
    field :correlation_id, non_neg_integer()
  end

  def encode(error) do
    %Error{
      error_code: error_code,
      previous_message_id: previous_message_id,
      error_message: error_message,
      timestamp: timestamp,
      correlation_id: correlation_id
    } = error

    [
      error_code,
      previous_message_id,
      error_message,
      timestamp,
      correlation_id
    ]
  end

  def encode_cbor(error) do
    error
    |> encode()
    |> CBOR.encode()
  end
end
