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

defmodule Astarte.FDO.Core.OwnerOnboarding.SignatureInfoTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.SignatureInfo
  alias COSE.Keys.ECC, as: COSEKeysECC

  describe "decode/1" do
    test "decodes es256 signature info" do
      raw = [-7, %CBOR.Tag{tag: :bytes, value: <<>>}]
      assert {:ok, :es256} = SignatureInfo.decode(raw)
    end

    test "decodes es384 signature info" do
      raw = [-35, %CBOR.Tag{tag: :bytes, value: <<>>}]
      assert {:ok, :es384} = SignatureInfo.decode(raw)
    end

    test "decodes eipd10 signature info" do
      gid = <<1, 2, 3, 4>>
      raw = [90, %CBOR.Tag{tag: :bytes, value: gid}]
      assert {:ok, {:eipd10, ^gid}} = SignatureInfo.decode(raw)
    end

    test "decodes eipd11 signature info" do
      gid = <<5, 6, 7, 8>>
      raw = [91, %CBOR.Tag{tag: :bytes, value: gid}]
      assert {:ok, {:eipd11, ^gid}} = SignatureInfo.decode(raw)
    end

    test "returns :error for unknown sig info" do
      raw = [999, %CBOR.Tag{tag: :bytes, value: <<>>}]
      assert :error = SignatureInfo.decode(raw)
    end
  end

  describe "encode/1" do
    test "encodes :es256" do
      assert [-7, %CBOR.Tag{tag: :bytes, value: <<>>}] = SignatureInfo.encode(:es256)
    end

    test "encodes :es384" do
      assert [-35, %CBOR.Tag{tag: :bytes, value: <<>>}] = SignatureInfo.encode(:es384)
    end

    test "encodes {:eipd10, gid}" do
      gid = <<0xAB, 0xCD>>
      assert [90, %CBOR.Tag{tag: :bytes, value: ^gid}] = SignatureInfo.encode({:eipd10, gid})
    end

    test "encodes {:eipd11, gid}" do
      gid = <<0xEF, 0x01>>
      assert [91, %CBOR.Tag{tag: :bytes, value: ^gid}] = SignatureInfo.encode({:eipd11, gid})
    end
  end

  describe "encode/decode roundtrip" do
    for sig_type <- [:es256, :es384] do
      test "roundtrips #{sig_type}" do
        sig = unquote(sig_type)
        assert {:ok, ^sig} = sig |> SignatureInfo.encode() |> SignatureInfo.decode()
      end
    end

    test "roundtrips {:eipd10, gid}" do
      original = {:eipd10, <<1, 2, 3, 4, 5, 6, 7, 8>>}
      assert {:ok, ^original} = original |> SignatureInfo.encode() |> SignatureInfo.decode()
    end
  end

  describe "from_device_signature/1" do
    test "returns :es256 for {:es256, key}" do
      key = COSEKeysECC.generate(:es256)
      assert :es256 = SignatureInfo.from_device_signature({:es256, key})
    end

    test "returns :es384 for {:es384, key}" do
      key = COSEKeysECC.generate(:es384)
      assert :es384 = SignatureInfo.from_device_signature({:es384, key})
    end

    test "returns epid type unchanged" do
      epid = {:eipd10, <<1, 2, 3, 4>>}
      assert ^epid = SignatureInfo.from_device_signature(epid)
    end
  end
end
