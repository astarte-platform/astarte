defmodule Astarte.Core.Triggers.DataTriggerTest do
  use ExUnit.Case

  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  @target %AMQPTriggerTarget{
    routing_key: "test"
  }

  defp make_trigger(overrides \\ %{}) do
    Map.merge(
      %DataTrigger{
        interface_id: "some-id",
        path_match_tokens: "/some/path",
        value_match_operator: :EQUAL_TO,
        known_value: 42,
        trigger_targets: [@target]
      },
      overrides
    )
  end

  test "are_congruent? returns true for identical triggers" do
    t = make_trigger()
    assert DataTrigger.are_congruent?(t, t)
  end

  test "are_congruent? returns true when trigger_targets differ but logic fields match" do
    t1 = make_trigger(%{trigger_targets: [@target]})
    t2 = make_trigger(%{trigger_targets: []})
    assert DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? returns false when interface_id differs" do
    t1 = make_trigger(%{interface_id: "id-a"})
    t2 = make_trigger(%{interface_id: "id-b"})
    refute DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? returns false when path_match_tokens differs" do
    t1 = make_trigger(%{path_match_tokens: "/a/b"})
    t2 = make_trigger(%{path_match_tokens: "/c/d"})
    refute DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? returns false when value_match_operator differs" do
    t1 = make_trigger(%{value_match_operator: :EQUAL_TO})
    t2 = make_trigger(%{value_match_operator: :NOT_EQUAL_TO})
    refute DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? returns false when known_value differs" do
    t1 = make_trigger(%{known_value: 1})
    t2 = make_trigger(%{known_value: 2})
    refute DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? works with :any_interface" do
    t1 = make_trigger(%{interface_id: :any_interface})
    t2 = make_trigger(%{interface_id: :any_interface})
    assert DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? works with :any_endpoint path_match_tokens" do
    t1 = make_trigger(%{path_match_tokens: :any_endpoint})
    t2 = make_trigger(%{path_match_tokens: :any_endpoint})
    assert DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? works with nil known_value" do
    t1 = make_trigger(%{known_value: nil})
    t2 = make_trigger(%{known_value: nil})
    assert DataTrigger.are_congruent?(t1, t2)
  end

  test "are_congruent? returns false when one known_value is nil and other is not" do
    t1 = make_trigger(%{known_value: nil})
    t2 = make_trigger(%{known_value: 42})
    refute DataTrigger.are_congruent?(t1, t2)
  end
end
