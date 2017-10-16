defmodule Astarte.Pairing.TestHelper do
  def random_hw_id do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
