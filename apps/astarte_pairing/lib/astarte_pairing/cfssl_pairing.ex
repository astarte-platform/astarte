defmodule Astarte.Pairing.CFSSLPairing do
  @moduledoc """
  Module implementing pairing using CFSSL
  """

  alias Astarte.Pairing.Config
  alias CFXXL.CertUtils
  alias CFXXL.Client
  alias CFXXL.Subject

  @doc """
  Perform the pairing for the device
  """
  def pair(csr, realm, extended_id) do
    device_common_name = "#{realm}/#{extended_id}"
    subject = %Subject{CN: device_common_name}

    {:ok, %{"certificate" => cert}} =
      Client.new(Config.cfssl_url())
      |> CFXXL.sign(csr, subject: subject, profile: "device")

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
  end
end
