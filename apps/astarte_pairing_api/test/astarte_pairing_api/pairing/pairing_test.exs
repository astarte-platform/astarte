defmodule Astarte.Pairing.API.PairingTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Pairing
  alias Astarte.Pairing.Mock

  describe "certficate request" do
    alias Astarte.Pairing.API.Pairing.Certificate

    @device_ip "2.3.4.5"
    @csr "testcsr"
    @valid_api_key Mock.valid_api_key()
    @invalid_api_key "invalid"

    @valid_attrs %{"csr" => @csr, "api_key" => @valid_api_key, "device_ip" => @device_ip}
    @no_csr_attrs %{"api_key" => @valid_api_key, "device_ip" => @device_ip}
    @invalid_api_key_attrs %{"csr" => @csr, "api_key" => @invalid_api_key, "device_ip" => @device_ip}

    test "pair/1 with valid data returns a Certificate" do
      assert {:ok, %Certificate{client_crt: crt}} = Pairing.pair(@valid_attrs)
      assert crt == Mock.certificate(@csr, @device_ip)
    end

    test "pair/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Pairing.pair(@no_csr_attrs)
      assert {:error, :unauthorized} = Pairing.pair(@invalid_api_key_attrs)
    end
  end
end
