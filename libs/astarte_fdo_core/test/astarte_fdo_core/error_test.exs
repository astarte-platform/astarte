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

defmodule Astarte.FDO.Core.ErrorTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Error

  @sample_error %Error{
    error_code: 100,
    previous_message_id: 5,
    error_message: "something went wrong",
    timestamp: nil,
    correlation_id: 42
  }

  describe "encode/1" do
    test "returns a list with all fields in order" do
      result = Error.encode(@sample_error)

      assert result == [100, 5, "something went wrong", nil, 42]
    end

    test "preserves nil timestamp" do
      [_, _, _, timestamp, _] = Error.encode(@sample_error)
      assert is_nil(timestamp)
    end
  end

  describe "encode_cbor/1" do
    test "returns a binary" do
      result = Error.encode_cbor(@sample_error)
      assert is_binary(result)
    end

    test "roundtrips through CBOR" do
      cbor = Error.encode_cbor(@sample_error)
      {:ok, decoded, ""} = CBOR.decode(cbor)

      assert decoded == Error.encode(@sample_error)
    end
  end
end
