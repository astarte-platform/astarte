defmodule Astarte.Core.MappingTest do
  use ExUnit.Case

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Mapping

  test "mapping with no type fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/valid"
    }

    assert %Ecto.Changeset{valid?: false, errors: [type: _]} =
             Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping with invalid type fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/valid",
      "type" => "invalid"
    }

    assert %Ecto.Changeset{valid?: false, errors: [type: _]} =
             Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping with invalid endpoint fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "//this/is/almost/%{ok}",
      "type" => "string"
    }

    assert %Ecto.Changeset{valid?: false, errors: [endpoint: _]} =
             Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping with invalid retention fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/valid",
      "type" => "string",
      "retention" => "invalid"
    }

    assert %Ecto.Changeset{valid?: false, errors: [retention: _]} =
             Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping with invalid reliability fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/valid",
      "type" => "string",
      "reliability" => "invalid"
    }

    assert %Ecto.Changeset{valid?: false, errors: [reliability: _]} =
             Mapping.changeset(%Mapping{}, params, opts)
  end

  test "valid mapping" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/this/is/%{ok}",
      "type" => "integer",
      "retention" => "stored",
      "reliability" => "guaranteed",
      "expiry" => 60,
      "database_retention_policy" => "use_ttl",
      "database_retention_ttl" => 60,
      "doc" => "The doc.",
      "description" => "The description."
    }

    assert %Ecto.Changeset{valid?: true} = changeset = Mapping.changeset(%Mapping{}, params, opts)
    assert {:ok, mapping} = Ecto.Changeset.apply_action(changeset, :insert)

    assert %Mapping{
             endpoint: "/this/is/%{ok}",
             value_type: :integer,
             retention: :stored,
             reliability: :guaranteed,
             expiry: 60,
             doc: "The doc.",
             description: "The description."
           } = mapping
  end

  test "legacy naming" do
    opts = opts_fixture()

    params = %{
      "path" => "/this/is/%{ok}",
      "type" => "double"
    }

    assert %Ecto.Changeset{valid?: true} = changeset = Mapping.changeset(%Mapping{}, params, opts)
    assert {:ok, mapping} = Ecto.Changeset.apply_action(changeset, :insert)

    assert %Mapping{
             endpoint: "/this/is/%{ok}",
             value_type: :double
           } = mapping
  end

  test "defaults" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/this/is/%{ok}",
      "type" => "datetime"
    }

    assert %Ecto.Changeset{valid?: true} = changeset = Mapping.changeset(%Mapping{}, params, opts)
    assert {:ok, mapping} = Ecto.Changeset.apply_action(changeset, :insert)

    assert %Mapping{
             endpoint: "/this/is/%{ok}",
             value_type: :datetime,
             retention: :discard,
             reliability: :unreliable,
             expiry: 0,
             database_retention_policy: :no_ttl,
             database_retention_ttl: nil,
             allow_unset: false
           } = mapping
  end

  test "mapping with no_ttl policy and valid database_retention_ttl set fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/valid",
      "type" => "string",
      "reliability" => "guaranteed",
      "database_retention_policy" => "no_ttl",
      "database_retention_ttl" => 80
    }

    assert %Ecto.Changeset{valid?: false, errors: [database_retention_policy: _]} =
             Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping with no_ttl policy and invalid database_retention_ttl set fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/valid",
      "type" => "string",
      "reliability" => "guaranteed",
      "database_retention_policy" => "no_ttl",
      "database_retention_ttl" => 0
    }

    assert %Ecto.Changeset{
             valid?: false,
             errors: [
               {:database_retention_policy, _},
               {:database_retention_ttl, _}
             ]
           } = Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping with no_ttl policy and no database_retention_ttl succeeds" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/valid",
      "type" => "string",
      "reliability" => "guaranteed",
      "database_retention_policy" => "no_ttl"
    }

    assert %Ecto.Changeset{valid?: true} = Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping with use_ttl policy and no database_retention_ttl fails" do
    opts = opts_fixture()

    params = %{
      "endpoint" => "/invalid",
      "type" => "string",
      "reliability" => "guaranteed",
      "database_retention_policy" => "use_ttl"
    }

    assert %Ecto.Changeset{
             valid?: false,
             errors: [
               {:database_retention_ttl, _}
             ]
           } = Mapping.changeset(%Mapping{}, params, opts)
  end

  test "mapping from legacy database result" do
    legacy_result = [
      endpoint: "/test",
      # integer
      value_type: 3,
      # unique
      reliability: 3,
      # stored
      retention: 3,
      expiry: 0,
      database_retention_policy: nil,
      database_retention_ttl: nil,
      allow_unset: false,
      explicit_timestamp: true,
      endpoint_id: <<24, 101, 36, 39, 201, 240, 51, 175, 45, 122, 166, 194, 132, 91, 176, 154>>,
      interface_id: <<3, 203, 231, 42, 212, 254, 30, 12, 159, 114, 187, 196, 29, 30, 5, 219>>
    ]

    expected_mapping = %Mapping{
      endpoint: "/test",
      value_type: :integer,
      reliability: :unique,
      retention: :stored,
      expiry: 0,
      database_retention_policy: :no_ttl,
      database_retention_ttl: nil,
      allow_unset: false,
      explicit_timestamp: true,
      description: nil,
      doc: nil,
      endpoint_id: <<24, 101, 36, 39, 201, 240, 51, 175, 45, 122, 166, 194, 132, 91, 176, 154>>,
      interface_id: <<3, 203, 231, 42, 212, 254, 30, 12, 159, 114, 187, 196, 29, 30, 5, 219>>
    }

    assert Mapping.from_db_result!(legacy_result) == expected_mapping
  end

  defp opts_fixture do
    interface_name = "com.Name"
    interface_major = 1
    interface_id = CQLUtils.interface_id(interface_name, interface_major)

    [interface_name: interface_name, interface_major: interface_major, interface_id: interface_id]
  end
end
