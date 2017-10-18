defmodule Astarte.Pairing.CertVerifierTest do
  use ExUnit.Case

  alias Astarte.Pairing.CertVerifier
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.TestHelper
  alias CFXXL.Client
  alias CFXXL.DName

  setup_all do
    cfxxl_client =
      Config.cfssl_url()
      |> Client.new()

    {:ok, %{"certificate" => ca_crt}} = CFXXL.info(cfxxl_client, "")

    {:ok, cfxxl_client: cfxxl_client, ca_crt: ca_crt}
  end

  test "valid certificate", %{cfxxl_client: cfxxl_client, ca_crt: ca_crt} do
    hw_id = TestHelper.random_hw_id()
    {:ok, %{"certificate" => valid_cert}} = CFXXL.newcert(cfxxl_client, [], %DName{O: "Hemera"}, CN: "test/#{hw_id}", profile: "device")

    assert {:ok, %{timestamp: timestamp, until: until}} = CertVerifier.verify(valid_cert, ca_crt)

    my_now =
      DateTime.utc_now()
      |> DateTime.to_unix(:milliseconds)

    assert_in_delta timestamp, my_now, 5000

    {:ok, %{"not_after" => not_after}} = CFXXL.certinfo(cfxxl_client, certificate: valid_cert)
    {:ok, not_after_datetime, 0} = DateTime.from_iso8601(not_after)
    not_after_unix = DateTime.to_unix(not_after_datetime, :milliseconds)

    assert until == not_after_unix
  end

  test "expired certificate", %{cfxxl_client: cfxxl_client, ca_crt: ca_crt} do
    hw_id = TestHelper.random_hw_id()
    {:ok, %{"certificate" => valid_cert}} = CFXXL.newcert(cfxxl_client, [], %DName{O: "Hemera"}, CN: "test/#{hw_id}", profile: "test-short-expiry")

    :timer.sleep(1500)

    assert {:error, :cert_expired} = CertVerifier.verify(valid_cert, ca_crt)
  end
end
