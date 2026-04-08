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

defmodule Astarte.PairingWeb.Controllers.OwnershipVoucherControllerTest do
  use Astarte.Cases.Conn, async: true
  use Astarte.Cases.Data
  use Mimic

  alias Astarte.Pairing.Config
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  import Astarte.Helpers.FDO

  @sample_key_name "owner_key"

  @sample_private_key_pem """
  -----BEGIN EC PRIVATE KEY-----
  MHcCAQEEIPKdthyV+2F5gPIqHyiQ9Wi1Y01r66/BbvnILFWehTRToAoGCCqGSM49
  AwEHoUQDQgAEGwrCWU3M3/Cxk0jMB4TmyQEaXLp+tqX42GsmeZ+7jeEWjHLFmEYH
  LC/GgcMr88CXA3/i64k0iiIMRRQ3osnV/A==
  -----END EC PRIVATE KEY-----
  """

  @sample_ownership_voucher_pem """
  -----BEGIN OWNERSHIP VOUCHER-----
  hRhlWL6GGGVQsfHY8DqfTPi0ayOpTPxm54GEggNDGR+SggJFRH8AAAGCBEMZH5KC
  DEEBa3AyNTYtZGV2aWNlgwoBWFswWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQb
  CsJZTczf8LGTSMwHhObJARpcun62pfjYayZ5n7uN4RaMcsWYRgcsL8aBwyvzwJcD
  f+LriTSKIgxFFDeiydX8gi9YINH8REeqEOOpCpH9Arx8yt1/2ZKICO5s8mo4AW2h
  Gfz2ggVYIENgeEjaDkp0mbAiC/jro5IUx9j0jtTEUNLm8M74YleDgVkBHjCCARow
  gcGgAwIBAgIDAeJAMAoGCCqGSM49BAMCMBYxFDASBgNVBAMMC1Rlc3QgRGV2aWNl
  MB4XDTI0MDEwMTAwMDAwMFoXDTM0MDEwMTAwMDAwMFowFjEUMBIGA1UEAwwLVGVz
  dCBEZXZpY2UwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQbCsJZTczf8LGTSMwH
  hObJARpcun62pfjYayZ5n7uN4RaMcsWYRgcsL8aBwyvzwJcDf+LriTSKIgxFFDei
  ydX8MAoGCCqGSM49BAMCA0gAMEUCIF+IuxL2kt310Im+OjbA/lNNG73qUX1CH22i
  5/WGPHz8AiEAuzPBY60mRQHyetxjA4Lx+Wkdm7NWWxzdfv+6uDhVhOiB0oRDoQEm
  oFichIIvWCBSpkHIqibg9oEqb9tnSTB0ABsn9mji099pWZIcvH0WdoIvWCCLI3XG
  98ZneM2FDlIJC7dH8MZSxltPfu4TkN7z6GIo1vaDCgNYTaUieCAWjHLFmEYHLC/G
  gcMr88CXA3/i64k0iiIMRRQ3osnV/CF4IBsKwllNzN/wsZNIzAeE5skBGly6fral
  +NhrJnmfu43hIAEBAgMmWEChODtvywnaQNZqZtAi+ukIDh06ZQxYk/BZ72qtX4Qt
  KgRKDMZ26gaTvdOSYOiWl+hL0gCbdyhXp5dySgYsHYEn
  -----END OWNERSHIP VOUCHER-----
  """

  @sample_load_params %{
    data: %{
      "ownership_voucher" => sample_voucher(),
      "key_name" => @sample_key_name,
      "key_algorithm" => "es256"
    }
  }

  setup :verify_on_exit!

  describe "/fdo/ownership_vouchers" do
    setup :register_setup

    test "returns 200 with the owner public key on a valid matching key", context do
      %{auth_conn: conn, register_path: path, realm_name: realm_name} = context

      {:ok, owner_cose_key} = COSE.Keys.from_pem(@sample_private_key_pem)
      {:ok, namespace} = Secrets.create_namespace(realm_name, :es256)
      :ok = Secrets.import_key(@sample_key_name, :es256, owner_cose_key, namespace: namespace)

      {:ok, %Key{public_pem: expected_public_key}} =
        Secrets.get_key(@sample_key_name, namespace: namespace)

      params = %{
        data: %{
          "ownership_voucher" => @sample_ownership_voucher_pem,
          "key_name" => @sample_key_name,
          "key_algorithm" => "es256"
        }
      }

      body =
        conn
        |> post(path, params)
        |> json_response(200)

      assert get_in(body, ["data", "public_key"]) == expected_public_key
    end

    test "returns 422 when the ownership_voucher field is missing", context do
      %{auth_conn: conn, register_path: path} = context

      params = update_in(@sample_load_params, [:data], &Map.delete(&1, "ownership_voucher"))

      conn
      |> post(path, params)
      |> response(422)
    end

    test "returns 422 when the key_name field is missing", context do
      %{auth_conn: conn, register_path: path} = context

      params = update_in(@sample_load_params, [:data], &Map.delete(&1, "key_name"))

      conn
      |> post(path, params)
      |> response(422)
    end

    test "returns 422 when the key does not exist in the secrets store", context do
      %{auth_conn: conn, register_path: path, realm_name: realm_name} = context

      stub(Secrets, :create_namespace, fn ^realm_name, :es256 ->
        {:ok, "fdo_owner_keys/#{realm_name}/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> :error end)

      conn
      |> post(path, @sample_load_params)
      |> response(422)
    end

    test "returns 422 when the key public bytes do not match the voucher's last entry", context do
      %{auth_conn: conn, register_path: path, realm_name: realm_name} = context

      wrong_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/#{realm_name}/ecdsa-p256",
        alg: :es256,
        public_pem: """
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEocPEIHIrn08VRO5zkkDztwp72Sw0
        BSm0mZeLgOKkHLUPdVFFlc0EO82b1/S2Cwzwh8MIDDx0CN2b+IBl5bRwOw==
        -----END PUBLIC KEY-----
        """
      }

      stub(Secrets, :create_namespace, fn ^realm_name, :es256 ->
        {:ok, "fdo_owner_keys/#{realm_name}/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, wrong_key} end)

      conn
      |> post(path, @sample_load_params)
      |> response(422)
    end

    test "returns a 404 error if FDO feature is disabled", context do
      %{auth_conn: conn, register_path: path} = context

      stub(Config, :enable_fdo!, fn -> false end)

      conn
      |> post(path, @sample_load_params)
      |> response(404)
    end
  end

  defp register_setup(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    register_path = ownership_voucher_path(conn, :register, realm_name)
    %{register_path: register_path}
  end

  describe "/fdo/owner_keys_for_voucher" do
    setup :owner_keys_for_voucher_setup

    test "returns 200 with a map of algorithm to key names", context do
      %{auth_conn: conn, path: path, realm_name: realm_name} = context

      stub(Secrets, :create_namespace, fn ^realm_name, :es256 ->
        {:ok, "fdo_owner_keys/#{realm_name}/ecdsa-p256"}
      end)

      stub(Secrets, :list_keys_names, fn _opts ->
        {:ok, [@sample_key_name, "another_key"]}
      end)

      body =
        conn
        |> post(path, %{data: %{"ownership_voucher" => sample_voucher()}})
        |> json_response(200)

      assert %{"es256" => [@sample_key_name, "another_key"]} = get_in(body, ["data"])
    end

    test "returns 200 with an empty key list when no keys are registered", context do
      %{auth_conn: conn, path: path, realm_name: realm_name} = context

      stub(Secrets, :create_namespace, fn ^realm_name, :es256 ->
        {:ok, "fdo_owner_keys/#{realm_name}/ecdsa-p256"}
      end)

      stub(Secrets, :list_keys_names, fn _opts -> {:ok, []} end)

      body =
        conn
        |> post(path, %{data: %{"ownership_voucher" => sample_voucher()}})
        |> json_response(200)

      assert %{"es256" => []} = get_in(body, ["data"])
    end

    test "returns 422 when the ownership_voucher field is missing", context do
      %{auth_conn: conn, path: path} = context

      conn
      |> post(path, %{data: %{}})
      |> response(422)
    end

    test "returns 404 when the FDO feature is disabled", context do
      %{auth_conn: conn, path: path} = context

      stub(Config, :enable_fdo!, fn -> false end)

      conn
      |> post(path, %{data: %{"ownership_voucher" => sample_voucher()}})
      |> response(404)
    end
  end

  describe "list_ownership_vouchers/2" do
    setup :store_sample_voucher
    setup :add_list_path

    test "returns the list of vouchers for the realm", context do
      %{auth_conn: conn, path: path} = context

      body =
        conn
        |> get(path)
        |> json_response(200)

      assert [ownership_voucher_result] = body["data"]
      assert UUID.string_to_binary!(ownership_voucher_result["guid"])
      assert ownership_voucher_result["status"] == "created"
      assert ownership_voucher_result["input_voucher"] == @sample_ownership_voucher_pem
    end
  end

  defp owner_keys_for_voucher_setup(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    path = ownership_voucher_path(conn, :owner_keys_for_voucher, realm_name)
    %{path: path}
  end

  defp store_sample_voucher(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    %{register_path: path} = register_setup(context)
    {:ok, owner_cose_key} = COSE.Keys.from_pem(@sample_private_key_pem)
    {:ok, namespace} = Secrets.create_namespace(realm_name, :es256)
    :ok = Secrets.import_key(@sample_key_name, :es256, owner_cose_key, namespace: namespace)

    params = %{
      data: %{
        "ownership_voucher" => @sample_ownership_voucher_pem,
        "key_name" => @sample_key_name,
        "key_algorithm" => "es256"
      }
    }

    conn
    |> post(path, params)
    |> json_response(200)

    :ok
  end

  defp add_list_path(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    path = ownership_voucher_path(conn, :list_ownership_vouchers, realm_name)
    %{path: path}
  end
end
