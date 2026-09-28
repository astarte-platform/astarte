defmodule Astarte.Core.GroupTest do
  use ExUnit.Case

  alias Astarte.Core.Group

  test "empty group name fails" do
    assert Group.valid_name?("") == false
  end

  test "group name with reserved prefixes fail" do
    assert Group.valid_name?("@other") == false
    assert Group.valid_name?("~other") == false
    assert Group.valid_name?("@~other") == false
    assert Group.valid_name?("~@other") == false
  end

  test "valid group names are accepted" do
    assert Group.valid_name?("plainname") == true
    assert Group.valid_name?("a/name-with@many*strange§characters") == true
    assert Group.valid_name?("astarte_is_not_reserved_anymore") == true
    assert Group.valid_name?("devices-either") == true
    assert Group.valid_name?("a~in-second-position-is-fine") == true
    assert Group.valid_name?("a@too") == true
    assert Group.valid_name?("🤔") == true
  end
end
