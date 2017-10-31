defmodule Astarte.Pairing.API.Pairing do
  @moduledoc """
  The Pairing context.
  """

  alias Astarte.Pairing.API.Pairing.CertificateRequest
  alias Astarte.Pairing.API.Pairing.Certificate
  alias Astarte.Pairing.API.Pairing.CertificateStatus
  alias Astarte.Pairing.API.Pairing.VerifyCertificateRequest
  alias Astarte.Pairing.API.RPC.AMQPClient
  alias Astarte.Pairing.API.Utils

  def pair(params) do
    changeset =
      %CertificateRequest{}
      |> CertificateRequest.changeset(params)

    if changeset.valid? do
      %CertificateRequest{csr: csr, api_key: api_key, device_ip: device_ip} = Ecto.Changeset.apply_changes(changeset)
      case AMQPClient.do_pairing(csr, api_key, device_ip) do
        {:ok, certificate} ->
          {:ok, %Certificate{client_crt: certificate}}

        {:error, %{error_name: "invalid_api_key"}} ->
          {:error, :unauthorized}

        {:error, %{} = error_map} ->
          {:error, Utils.error_map_into_changeset(changeset, error_map)}

        _other ->
          {:error, :rpc_error}
      end

    else
      {:error, %{changeset | action: :create}}
    end
  end

  def verify_certificate(params) do
    changeset =
      %VerifyCertificateRequest{}
      |> VerifyCertificateRequest.changeset(params)

    if changeset.valid? do
      %VerifyCertificateRequest{certificate: certificate} = Ecto.Changeset.apply_changes(changeset)
      case AMQPClient.verify_certificate(certificate) do
        {:ok, %{valid: valid, timestamp: timestamp, cause: cause, until: until, details: details}} ->
          cert_status =
            %CertificateStatus{valid: valid,
                               timestamp: timestamp,
                               cause: cause,
                               until: until,
                               details: details}

          {:ok, cert_status}

        {:error, _reason} ->
          {:error, :rpc_error}
      end
    else
      {:error, %{changeset | action: :create}}
    end
  end
end
