defmodule Astarte.Pairing.CFSSLPairingTest do
  use ExUnit.Case

  alias Astarte.Pairing.CFSSLPairing

  test "revoke should never fail" do
    assert CFSSLPairing.revoke("invalidserial", "invalidaki") == :ok
    assert CFSSLPairing.revoke(:null, :null) == :ok
  end
end
