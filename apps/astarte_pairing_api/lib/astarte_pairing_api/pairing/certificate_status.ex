defmodule Astarte.Pairing.API.Pairing.CertificateStatus do
  @enforce_keys [:valid, :timestamp, :until, :cause, :details]
  defstruct [:valid, :timestamp, :until, :cause, :details]
end
