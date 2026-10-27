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

defmodule Astarte.FDO.Core.PublicKeyTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.PublicKey

  @sample_body <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42,
                 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62,
                 63, 64>>

  defp make_pk(type, encoding, body \\ @sample_body) do
    %PublicKey{type: type, encoding: encoding, body: body}
  end

  describe "encode/1 and decode/1 roundtrip" do
    for {type, enc} <- [
          secp256r1: :x509,
          secp384r1: :x509,
          rsa2048restr: :x509,
          rsa2048restr: :crypto,
          rsapkcs: :x509,
          rsapss: :x509,
          secp256r1: :cosekey
        ] do
      test "#{type} / #{enc}" do
        pk = make_pk(unquote(type), unquote(enc))
        encoded = PublicKey.encode(pk)

        assert {:ok, ^pk} = PublicKey.decode(encoded)
      end
    end

    test "secp256r1 / x5chain with a list of certificates" do
      certs = [:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(48)]
      pk = make_pk(:secp256r1, :x5chain, certs)
      encoded = PublicKey.encode(pk)

      assert {:ok, decoded} = PublicKey.decode(encoded)
      assert decoded.type == :secp256r1
      assert decoded.encoding == :x5chain
      assert decoded.body == certs
    end
  end

  describe "encode_cbor/1 and decode_cbor/1 roundtrip" do
    test "roundtrips secp256r1 / x509 key" do
      pk = make_pk(:secp256r1, :x509)
      cbor = PublicKey.encode_cbor(pk)

      assert is_binary(cbor)
      assert {:ok, ^pk} = PublicKey.decode_cbor(cbor)
    end
  end

  describe "decode_cbor/1 error cases" do
    test "returns :error for invalid CBOR" do
      assert :error = PublicKey.decode_cbor(<<0xFF>>)
    end

    test "returns :error for CBOR with unknown type" do
      bad_cbor = CBOR.encode([99, 1, %CBOR.Tag{tag: :bytes, value: <<1, 2, 3>>}])
      assert :error = PublicKey.decode_cbor(bad_cbor)
    end

    test "returns :error for CBOR with unknown encoding" do
      bad_cbor = CBOR.encode([10, 99, %CBOR.Tag{tag: :bytes, value: <<1, 2, 3>>}])
      assert :error = PublicKey.decode_cbor(bad_cbor)
    end

    test "returns :error for wrong structure" do
      bad_cbor = CBOR.encode([10, 1])
      assert :error = PublicKey.decode_cbor(bad_cbor)
    end
  end

  describe "decode/1 error cases" do
    test "returns :error for non-list input" do
      assert :error = PublicKey.decode("not a list")
    end

    test "returns :error for body without byte tag in x509 encoding" do
      bad_encoded = [10, 1, "not_a_byte_tag"]
      assert :error = PublicKey.decode(bad_encoded)
    end
  end
end
