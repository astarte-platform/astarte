defmodule Astarte.RealmManagementWeb.GraphQL.Types.CommonTypesTest do
  use ExUnit.Case, async: true

  defmodule TestSchema do
    use Absinthe.Schema
    import_types(Astarte.RealmManagementWeb.GraphQL.Types.CommonTypes)

    query do
      field :echo_json, :json do
        arg(:input, :json)

        resolve(fn %{input: input}, _ ->
          {:ok, input}
        end)
      end

      field :get_json, :json do
        resolve(fn _, _ ->
          {:ok, %{"a" => 1, "nested" => ["b", 2]}}
        end)
      end
    end
  end

  test "serializes JSON data correctly" do
    query = """
    query {
      getJson
    }
    """

    assert {:ok, %{data: %{"getJson" => %{"a" => 1, "nested" => ["b", 2]}}}} =
             Absinthe.run(query, TestSchema)
  end

  test "parses JSON variables correctly" do
    query = """
    query Echo($input: Json) {
      echoJson(input: $input)
    }
    """

    variables = %{
      "input" => %{
        "string" => "test",
        "integer" => 42,
        "float" => 3.14,
        "boolean" => true,
        "null" => nil,
        "list" => ["a", 1, false],
        "nested" => %{"key" => "value"}
      }
    }

    assert {:ok, %{data: %{"echoJson" => parsed}}} =
             Absinthe.run(query, TestSchema, variables: variables)

    assert parsed == variables["input"]
  end

  test "parses inline JSON arguments correctly" do
    query = """
    query {
      echoJson(input: {
        string: "test", 
        integer: 42, 
        float: 3.14, 
        boolean: true, 
        list: ["a", 1, false], 
        nested: {key: "value"}
      })
    }
    """

    expected = %{
      "string" => "test",
      "integer" => 42,
      "float" => 3.14,
      "boolean" => true,
      "list" => ["a", 1, false],
      "nested" => %{"key" => "value"}
    }

    assert {:ok, %{data: %{"echoJson" => parsed}}} =
             Absinthe.run(query, TestSchema)

    assert parsed == expected
  end
end
