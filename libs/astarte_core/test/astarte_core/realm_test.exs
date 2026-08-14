defmodule Astarte.Core.RealmTest do
  use ExUnit.Case

  alias Astarte.Core.Realm

  test "empty realm name is rejected" do
    assert Realm.valid_name?("") == false
  end

  test "realm name with symbols are rejected" do
    assert Realm.valid_name?("my_realm") == false
    assert Realm.valid_name?("my-realm") == false
    assert Realm.valid_name?("my/realm") == false
    assert Realm.valid_name?("my@realm") == false
    assert Realm.valid_name?("🤔") == false
  end

  test "reserved realm name are rejected" do
    assert Realm.valid_name?("astarte") == false
    assert Realm.valid_name?("system") == false
    assert Realm.valid_name?("system_schema") == false
    assert Realm.valid_name?("system_other") == false
  end

  test "realm name that are longer than 48 valid characters are rejected" do
    # 48 characters
    assert Realm.valid_name?("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") == true
    # 49 characters
    assert Realm.valid_name?("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") == false
  end

  test "valid realm names are accepted" do
    assert Realm.valid_name?("goodrealmname") == true
  end
end
