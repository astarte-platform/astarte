defmodule Astarte.Core.Triggers.PolicyProtobufTest do
  use ExUnit.Case

  describe "payload serialized with ExProtobuf" do
    test "still works for ErrorRange" do
      alias Astarte.Core.Triggers.PolicyProtobuf.ErrorRange

      serialized_error = <<10, 4, 162, 3, 164, 3>>

      error = %ErrorRange{
        error_codes: [418, 420]
      }

      assert ErrorRange.encode(error) == serialized_error
      assert ErrorRange.decode(serialized_error) == error
    end

    test "still works for ErrorKeyword" do
      alias Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword

      serialized_error = <<8, 2>>

      error = %ErrorKeyword{
        keyword: :CLIENT_ERROR
      }

      assert ErrorKeyword.encode(error) == serialized_error
      assert ErrorKeyword.decode(serialized_error) == error
    end

    test "still works for Handler" do
      alias Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword
      alias Astarte.Core.Triggers.PolicyProtobuf.Handler

      serialized_handler = <<8, 2, 18, 2, 8, 2>>

      handler = %Handler{
        on: {:error_keyword, %ErrorKeyword{keyword: :CLIENT_ERROR}},
        strategy: :RETRY
      }

      assert Handler.encode(handler) == serialized_handler
      assert Handler.decode(serialized_handler) == handler
    end

    test "still works for Policy" do
      alias Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword
      alias Astarte.Core.Triggers.PolicyProtobuf.Handler
      alias Astarte.Core.Triggers.PolicyProtobuf.Policy

      serialized_policy =
        <<10, 8, 97, 95, 112, 111, 108, 105, 99, 121, 16, 10, 42, 6, 8, 2, 18, 2, 8, 2>>

      policy = %Policy{
        name: "a_policy",
        maximum_capacity: 10,
        error_handlers: [
          %Handler{on: {:error_keyword, %ErrorKeyword{keyword: :CLIENT_ERROR}}, strategy: :RETRY}
        ]
      }

      assert Policy.encode(policy) == serialized_policy
      assert Policy.decode(serialized_policy) == policy
    end
  end
end
