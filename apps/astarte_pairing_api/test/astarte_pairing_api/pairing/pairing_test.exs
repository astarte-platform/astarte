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

    test "pair/1 with malformed data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Pairing.pair(@no_csr_attrs)
    end

    test "pair/1 with an invalid api key returns an unauthorized error" do
      assert {:error, :unauthorized} = Pairing.pair(@invalid_api_key_attrs)
    end
  end

  describe "certificate verification" do
    alias Astarte.Pairing.API.Pairing.CertificateStatus

    @valid_crt Mock.valid_crt()

    @valid_attrs %{certificate: @valid_crt}
    @no_certificate_attrs %{}
    @nil_certificate_attrs %{certificate: nil}
    @invalid_crt_attrs %{certificate: "invalid"}

    test "verify_certificate/1 with valid certificate returns a CertificateStatus" do
      assert {:ok,
        %CertificateStatus{
          valid: true,
          until: _until,
          timestamp: _timestamp}} = Pairing.verify_certificate(@valid_attrs)
    end

    test "verify_certificate/1 with malformed attrs returns an error changeset" do
      assert {:error, %Ecto.Changeset{}} = Pairing.verify_certificate(@no_certificate_attrs)
      assert {:error, %Ecto.Changeset{}} = Pairing.verify_certificate(@nil_certificate_attrs)
    end

    test "verify_certificate/1 with invalid crt returns an invalid CertificateStatus" do
      assert {:ok,
        %CertificateStatus{valid: false,
          timestamp: _timestamp,
          cause: _cause,
          details: _details}} = Pairing.verify_certificate(@invalid_crt_attrs)
    end
  end
end
