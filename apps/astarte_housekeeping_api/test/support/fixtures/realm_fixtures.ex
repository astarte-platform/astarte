#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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
defmodule Astarte.Housekeeping.API.Fixtures.Realm do
  alias Astarte.Housekeeping.API.Realms

  @pubkey """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE6ssZpULEsn+wSQdc+DI2+4aj98a1hDKM
  +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
  -----END PUBLIC KEY-----
  """
  def pubkey, do: @pubkey

  @valid_attrs %{
    realm_name: "mytestrealm",
    jwt_public_key_pem: @pubkey,
    device_registration_limit: 42,
    datastream_maximum_storage_retention: 42
  }

  def realm_fixture(attrs \\ %{}) do
    {:ok, realm} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Realms.create_realm()

    realm
  end
end
