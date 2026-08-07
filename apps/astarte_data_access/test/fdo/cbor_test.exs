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

defmodule Astarte.DataAccess.FDO.CBORTest do
  use ExUnit.Case, async: true

  alias Astarte.DataAccess.FDO.CBOR.Encoded, as: FDOCBORType
  alias Astarte.FDO.Core.Hash

  # Use Hash as the codec module since it has encode_cbor/1 and decode_cbor/1
  @params FDOCBORType.init(using: Hash)

  describe "init/1" do
    test "stores the module in params" do
      params = FDOCBORType.init(using: Hash)
      assert %{module: Hash} = params
    end
  end

  describe "type/1" do
    test "returns :binary" do
      assert :binary = FDOCBORType.type(@params)
    end
  end

  describe "cast/2" do
    test "passes through nil" do
      assert {:ok, nil} = FDOCBORType.cast(nil, @params)
    end

    test "passes through any value unchanged" do
      hash = Hash.new(:sha256, "test")
      assert {:ok, ^hash} = FDOCBORType.cast(hash, @params)
    end
  end

  describe "dump/3" do
    test "encodes a valid value to CBOR binary" do
      hash = Hash.new(:sha256, "hello")
      assert {:ok, binary} = FDOCBORType.dump(hash, nil, @params)
      assert is_binary(binary)
    end

    test "returns {:ok, nil} for nil" do
      assert {:ok, nil} = FDOCBORType.dump(nil, nil, @params)
    end
  end

  describe "load/3" do
    test "decodes CBOR binary back to the original value" do
      original = Hash.new(:sha256, "roundtrip")
      {:ok, cbor_binary} = FDOCBORType.dump(original, nil, @params)

      assert {:ok, loaded} = FDOCBORType.load(cbor_binary, nil, @params)
      assert loaded == original
    end

    test "returns {:ok, nil} for nil" do
      assert {:ok, nil} = FDOCBORType.load(nil, nil, @params)
    end

    test "returns :error for non-binary input" do
      assert :error = FDOCBORType.load(42, nil, @params)
    end
  end
end
