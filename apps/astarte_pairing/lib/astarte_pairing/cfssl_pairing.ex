defmodule Astarte.Pairing.CFSSLPairing do
  @moduledoc """
  Module implementing pairing using CFSSL
  """

  alias Astarte.Pairing.Config
  alias CFXXL.CertUtils
  alias CFXXL.Client
  alias CFXXL.Subject

  require Logger

  @doc """
  Perform the pairing for the device
  """
  def pair(csr, realm, extended_id) do
    device_common_name = "#{realm}/#{extended_id}"
    subject = %Subject{CN: device_common_name}

    case CFXXL.sign(client(), csr, subject: subject, profile: "device") do
      {:ok, %{"certificate" => cert}} ->
        aki = CertUtils.authority_key_identifier!(cert)
        serial = CertUtils.serial_number!(cert)
        cn = CertUtils.common_name!(cert)

        if cn == device_common_name do
          {:ok, %{cert: cert,
                  aki: aki,
                  serial: serial}}
        else
          {:error, :invalid_common_name}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # If it was not present in the DB, no need to revoke it
  def revoke(:null, :null), do: :ok
  def revoke(serial, aki) do
    case CFXXL.revoke(client(), serial, aki, "superseded") do
      # Don't fail even if we couldn't revoke, just warn
      {:error, reason} ->
        Logger.warn("Failed to revoke certificate with serial #{serial} and AKI #{aki}: #{inspect(reason)}")
        :ok

      :ok -> :ok
    end
  end

  defp client do
    Config.cfssl_url()
    |> Client.new()
  end
end
