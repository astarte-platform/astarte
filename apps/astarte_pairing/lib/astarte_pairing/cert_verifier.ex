#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Pairing.CertVerifier do
  @moduledoc """
  This module helps to verify the validity of a certificate
  """

  alias CFXXL.CertUtils

  @doc """
  Verifies the validity of the given `pem_certificate` against `ca_pem_cert`.

  Returns:
  - `{:ok, %{timestamp: timestamp, until: until}` if the certificate is valid.
  `timestamp` contains the timestamp of the verification, `until` contains the certificate
  expiration. Both are represented in milliseconds from epoch UTC.
  - `{:error, reason}` if the certificate isn't valid.
  """
  def verify(pem_cert, ca_pem_cert) do
    with {:ok, der_cert} <- extract_der(pem_cert),
         {:ok, ca_der_cert} <- extract_der(ca_pem_cert) do
      case :public_key.pkix_path_validation(ca_der_cert, [der_cert], []) do
        {:ok, _} ->
          timestamp =
            DateTime.utc_now()
            |> DateTime.to_unix(:milliseconds)

          until =
            CertUtils.not_after!(pem_cert)
            |> DateTime.to_unix(:milliseconds)

          {:ok, %{timestamp: timestamp, until: until}}

        {:error, {:bad_cert, reason}} ->
          {:error, reason}
      end
    end
  end

  defp extract_der(pem_certificate) do
    case :public_key.pem_decode(pem_certificate) do
      [{:Certificate, der, :not_encrypted}] -> {:ok, der}
      _other -> {:error, :invalid_certificate}
    end
  end
end
