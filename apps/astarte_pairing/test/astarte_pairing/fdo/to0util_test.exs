defmodule Astarte.Pairing.TO0UtilTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.TO0Util

  describe "get_nonce_from_hello_ack/1" do
    test "returns nonce for actual FDO HelloAck CBOR payload (binary nonce)" do
      valid_nonce = <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
      hello_ack_cbor = CBOR.encode([%CBOR.Tag{tag: :bytes, value: valid_nonce}])
      assert {:ok, ^valid_nonce} = TO0Util.get_nonce_from_hello_ack(hello_ack_cbor)
    end

    test "fails with wrong length CBOR body" do
      invalid_nonce = <<1, 2, 3, 4, 5, 6, 7, 8>>
      hello_ack_cbor = CBOR.encode([%CBOR.Tag{tag: :bytes, value: invalid_nonce}])

      assert {:error, {:wrong_cbor_size, ^invalid_nonce}} =
               TO0Util.get_nonce_from_hello_ack(hello_ack_cbor)
    end

    test "fails with non-CBOR binary" do
      invalid_nonce = <<1, 2, 3, 4, 5, 6, 7, 8>>

      assert {:error, {:unexpected_body_format, _}} =
               TO0Util.get_nonce_from_hello_ack(invalid_nonce)

      wrong_cbor2 =
        CBOR.encode([
          %CBOR.Tag{
            tag: :bytes,
            value: <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
          },
          %CBOR.Tag{
            tag: :bytes,
            value: <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
          }
        ])

      assert {:error, {:unexpected_body_format, _}} =
               TO0Util.get_nonce_from_hello_ack(wrong_cbor2)
    end
  end
end
