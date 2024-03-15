#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.Pairing.CFSSLCredentials do
  @moduledoc """
  Module implementing pairing using CFSSL
  """

  alias Astarte.Pairing.Config
  alias CFXXL.CertUtils
  alias CFXXL.Client
  alias CFXXL.Subject

  require Logger

  @doc """
  Signs the csr and returns the certificate data
  """
  def get_certificate(csr, realm, encoded_device_id) do
    device_common_name = "#{realm}/#{encoded_device_id}"
    subject = %Subject{CN: device_common_name}

    case CFXXL.sign(client(), csr, subject: subject, profile: "device") do
      {:ok, %{"certificate" => cert}} ->
        aki = CertUtils.authority_key_identifier!(cert)
        serial = CertUtils.serial_number!(cert)
        cn = CertUtils.common_name!(cert)

        if cn == device_common_name do
          {:ok, %{cert: cert, aki: aki, serial: serial}}
        else
          {:error, :invalid_common_name}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # If it was not present in the DB, no need to revoke it
  def revoke(nil, nil), do: :ok

  def revoke(serial, aki) do
    case CFXXL.revoke(client(), serial, aki, "superseded") do
      # Don't fail even if we couldn't revoke, just warn
      {:error, reason} ->
        Logger.warning(
          "Failed to revoke certificate with serial #{serial} and AKI #{aki}: #{inspect(reason)}"
        )

        :ok

      :ok ->
        :ok
    end
  end

  def ca_cert do
    case CFXXL.info(client(), "", profile: "device") do
      {:ok, %{"certificate" => cert}} ->
        {:ok, cert}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp client do
    Config.cfssl_url!()
    |> Client.new()
  end
end
