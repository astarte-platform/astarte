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

defmodule Astarte.Pairing.API.CertVerifier do
  @moduledoc """
  This module helps to verify the validity of a certificate
  """

  alias CFXXL.CertUtils

  @doc """
  Verifies the validity of the given `pem_certificate` against `ca_pem_cert`.

  Returns:
  - `{:ok, %{valid: true, timestamp: timestamp, until: until}` if the certificate is valid.
  `timestamp` contains the timestamp of the verification, `until` contains the certificate
  expiration. Both are represented in milliseconds from epoch UTC.
  - `{:ok, %{valid: false, timestamp: timestamp, reason: reason}` if the certificate isn't valid.
  - `{:error, :invalid_certificate}` if the certificate can't be decoded.
  """
  def verify(pem_cert, ca_pem_cert) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)

    with {:ok, der_cert} <- extract_der(pem_cert),
         {:ok, ca_der_cert} <- extract_der(ca_pem_cert),
         {:ok, _} <- :public_key.pkix_path_validation(ca_der_cert, [der_cert], []) do
      until =
        CertUtils.not_after!(pem_cert)
        |> DateTime.to_unix(:millisecond)

      {:ok, %{valid: true, timestamp: timestamp, until: until}}
    else
      {:error, {:bad_cert, reason}} ->
        {:ok, %{valid: false, timestamp: timestamp, reason: reason}}

      {:error, reason} ->
        {:ok, %{valid: false, timestamp: timestamp, reason: reason}}
    end
  end

  defp extract_der(pem_certificate) do
    case :public_key.pem_decode(pem_certificate) do
      [{:Certificate, der, :not_encrypted}] -> {:ok, der}
      _other -> {:error, :invalid_certificate}
    end
  end
end
