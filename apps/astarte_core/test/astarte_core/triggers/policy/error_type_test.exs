defmodule Astarte.Core.Triggers.Policy.ErrorTypeTest do
  use ExUnit.Case

  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.ErrorType

  test "cast/1 handles all valid and invalid input shapes" do
    assert {:ok, %ErrorKeyword{keyword: "any_error"}} = ErrorType.cast("any_error")
    assert {:error, _} = ErrorType.cast("invalid_keyword")

    assert {:ok, %ErrorKeyword{keyword: "client_error"}} =
             ErrorType.cast(%{"keyword" => "client_error"})

    assert {:error, _} = ErrorType.cast(%{"keyword" => "invalid"})

    assert {:ok, %ErrorRange{error_codes: [400, 500]}} = ErrorType.cast([400, 500])
    assert {:error, _} = ErrorType.cast([])
    assert {:error, _} = ErrorType.cast([200])

    assert {:ok, %ErrorRange{error_codes: [400, 500]}} =
             ErrorType.cast(%{"error_codes" => [400, 500]})

    assert {:error, _} = ErrorType.cast(%{"error_codes" => []})
  end

  test "dump/1 and load/1 handle keyword and range inputs" do
    assert {:ok, %ErrorKeyword{keyword: "any_error"}} = ErrorType.dump("any_error")
    assert {:ok, %ErrorRange{error_codes: [400, 500]}} = ErrorType.dump([400, 500])

    assert {:ok, %ErrorKeyword{keyword: "any_error"}} = ErrorType.load("any_error")
    assert {:ok, %ErrorRange{error_codes: [400, 500]}} = ErrorType.load([400, 500])
  end
end
