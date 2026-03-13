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

defmodule Astarte.Pairing.FDO.OpenBao.OpenBaoTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OpenBao
  alias Astarte.Pairing.FDO.OpenBao.Core

  test "request with invalid auth token is rejected by OpenBao" do
    key_name = "some_key"
    key_type = :ec384

    key_opts = [
      {:auth_token, "invalid_token"}
    ]

    assert {:error, :http_error} == OpenBao.create_keypair(key_name, key_type, key_opts)
  end

  test "successfully create and delete a key pair in OpenBao" do
    key_name = "some_key"
    key_type = :ec384
    key_type_to_string = Core.key_type_to_string(key_type)
    allow_key_export_and_backup = true

    key_opts = [
      {:allow_key_export_and_backup, allow_key_export_and_backup}
    ]

    assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, key_opts)

    assert %{
             "name" => ^key_name,
             "type" => ^key_type_to_string,
             "exportable" => ^allow_key_export_and_backup,
             "allow_plaintext_backup" => ^allow_key_export_and_backup
           } = key_data

    assert {:ok, %{}} == cleanup_key(key_name)
  end

  test "failure upon creation of a key of invalid type is notified" do
    key_name = "some_invalid_key"
    key_type = :wrong_type

    assert {:error, :unsupported_key_type} == OpenBao.create_keypair(key_name, key_type)
  end

  defp cleanup_key(key_name) do
    OpenBao.enable_key_deletion(key_name)
    OpenBao.delete_key(key_name)
  end
end
