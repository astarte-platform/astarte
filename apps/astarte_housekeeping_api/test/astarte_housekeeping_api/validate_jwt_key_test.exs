# Copyright 2020 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.Housekeeping.API.ValidateJWTKeyTest do
  alias Astarte.Housekeeping.API.Config
  alias Astarte.Housekeeping.API.Config.JWTPublicKeyPEMType
  use ExUnit.Case
  @pubkeypath "pubkey_file.txt"

  @pubkey """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE6ssZpULEsn+wSQdc+DI2+4aj98a1hDKM
  +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
  -----END PUBLIC KEY-----
  """

  describe "JWT key is set" do
    setup do
      Config.put_jwt_public_key_pem(@pubkey)

      on_exit(fn ->
        Config.reload_jwt_public_key_pem()
      end)
    end

    test "can be read" do
      assert Config.validate_jwt_public_key_pem!() == :ok
      assert Config.jwt_public_key_pem!() == @pubkey
    end
  end

  describe "JWT path is set" do
    setup do
      File.open!(@pubkeypath, [:write])
      File.write!(@pubkeypath, @pubkey)

      {:ok, key} = JWTPublicKeyPEMType.cast(@pubkeypath)
      Config.put_jwt_public_key_pem(key)

      on_exit(fn ->
        Config.reload_jwt_public_key_pem()
        File.rm!(@pubkeypath)
      end)
    end

    test "can read from path" do
      assert JWTPublicKeyPEMType.cast(@pubkeypath) == {:ok, @pubkey}
    end

    test "JWT path is invalid" do
      assert JWTPublicKeyPEMType.cast("invalid/path/") == :error
    end

    test "invalid entry" do
      assert JWTPublicKeyPEMType.cast([]) == :error
    end

    test "key can be read" do
      assert JWTPublicKeyPEMType.cast(@pubkey) == {:ok, @pubkey}
      assert Config.jwt_public_key_pem!() == @pubkey
    end
  end
end
