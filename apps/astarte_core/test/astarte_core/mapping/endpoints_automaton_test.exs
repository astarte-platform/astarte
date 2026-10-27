defmodule Astarte.Core.Mapping.EndpointsAutomatonTest do
  use ExUnit.Case
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton

  @valid_interface """
  {
   "interface_name": "com.ispirata.Hemera.DeviceLog",
   "version_major": 1,
   "version_minor": 0,
   "type": "datastream",
   "quality": "producer",
   "mappings": [
       {
           "path": "/message",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/timestamp",
           "type": "datetime",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/monotonicTimestamp",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/applicationId",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/pid",
           "type": "integer",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/cmdLine",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/filterRules/%{ruleId}/%{filterKey}/value",
           "type": "string"
       },
       {
           "path": "/test/%{ind}/v",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/test2/pluto/v",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       }
   ]
  }
  """

  @invalid_interface """
  {
   "interface_name": "com.ispirata.Hemera.DeviceLog",
   "version_major": 1,
   "version_minor": 0,
   "type": "datastream",
   "quality": "producer",
   "mappings": [
       {
           "path": "/message",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/timestamp",
           "type": "datetime",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/monotonicTimestamp",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/applicationId",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/pid",
           "type": "integer",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/cmdLine",
           "type": "string",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/filterRules/%{ruleId}/%{filterKey}/value",
           "type": "string"
       },
       {
           "path": "/test/%{ind}/v",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       },
       {
           "path": "/test/pluto/v",
           "type": "longinteger",
           "reliability": "guaranteed",
           "retention": "stored"
       }
   ]
  }
  """

  @test_draft_interface_a_0 """
    {
      "interface_name": "com.ispirata.Draft",
      "version_major": 0,
      "version_minor": 2,
      "type": "properties",
      "quality": "consumer",
      "mappings": [
        {
          "path": "/filterRules/%{ruleId}/%{filterKey}/value",
          "type": "string",
          "allow_unset": true
        },
        {
          "path": "/filterRules/%{ruleId}/%{filterKey}/foo",
          "type": "boolean",
          "allow_unset": false
        }
      ]
    }
  """

  @parametric_overlaps [
    %Mapping{
      allow_unset: false,
      description: nil,
      doc: nil,
      endpoint: "/some/%{param}/here",
      endpoint_id: <<229, 20, 231, 215, 188, 179, 148, 95, 139, 75, 126, 37, 180, 103, 211, 14>>,
      expiry: 0,
      explicit_timestamp: false,
      interface_id: <<139, 163, 99, 132, 204, 35, 51, 240, 194, 202, 102, 233, 32, 47, 86, 78>>,
      path: nil,
      reliability: :unreliable,
      retention: :discard,
      type: nil,
      value_type: :double
    },
    %Mapping{
      allow_unset: false,
      description: nil,
      doc: nil,
      endpoint: "/some/thing",
      endpoint_id: <<172, 209, 44, 141, 3, 42, 31, 121, 211, 86, 97, 253, 135, 225, 57, 129>>,
      expiry: 0,
      explicit_timestamp: false,
      interface_id: <<139, 163, 99, 132, 204, 35, 51, 240, 194, 202, 102, 233, 32, 47, 86, 78>>,
      path: nil,
      reliability: :unreliable,
      retention: :discard,
      type: nil,
      value_type: :double
    }
  ]

  @inverted_parametric_overlaps [
    %Mapping{
      allow_unset: false,
      description: nil,
      doc: nil,
      endpoint: "/some/%{param}",
      endpoint_id: <<229, 20, 231, 215, 188, 179, 148, 95, 139, 75, 126, 37, 180, 103, 211, 14>>,
      expiry: 0,
      explicit_timestamp: false,
      interface_id: <<139, 163, 99, 132, 204, 35, 51, 240, 194, 202, 102, 233, 32, 47, 86, 78>>,
      path: nil,
      reliability: :unreliable,
      retention: :discard,
      type: nil,
      value_type: :double
    },
    %Mapping{
      allow_unset: false,
      description: nil,
      doc: nil,
      endpoint: "/some/thing/here",
      endpoint_id: <<172, 209, 44, 141, 3, 42, 31, 121, 211, 86, 97, 253, 135, 225, 57, 129>>,
      expiry: 0,
      explicit_timestamp: false,
      interface_id: <<139, 163, 99, 132, 204, 35, 51, 240, 194, 202, 102, 233, 32, 47, 86, 78>>,
      path: nil,
      reliability: :unreliable,
      retention: :discard,
      type: nil,
      value_type: :double
    }
  ]

  @double_parametric_overlaps [
    %Mapping{
      endpoint: "/some/%{param}"
    },
    %Mapping{
      endpoint: "/%{some}/param"
    }
  ]

  @alias_parametric_overlaps [
    %Mapping{
      endpoint: "/param/%{some_param}"
    },
    %Mapping{
      endpoint: "/param/%{some_other_param}"
    }
  ]

  @endpoint_similar_tokens [
    %Mapping{
      endpoint: "/b/%{a}/%{b}/a"
    },
    %Mapping{
      endpoint: "/a/a/a/b"
    },
    %Mapping{
      endpoint: "/a/a/b"
    },
    %Mapping{
      endpoint: "/a/b"
    }
  ]

  test "build endpoints automaton" do
    {:ok, params} = Jason.decode(@test_draft_interface_a_0)

    {:ok, document} =
      Interface.changeset(%Interface{}, params)
      |> Ecto.Changeset.apply_action(:insert)

    assert {status, automaton} = EndpointsAutomaton.build(document.mappings)
    assert EndpointsAutomaton.lint(document.mappings) == []
    assert EndpointsAutomaton.valid?(automaton, document.mappings) == true
    assert status == :ok

    assert Enum.count(elem(automaton, 0)) == 5
    assert Enum.count(elem(automaton, 1)) == 2
  end

  test "parametric endpoints that can overlap for a given parameter choice are marked as overlapping" do
    assert {:error, :overlapping_mappings} = EndpointsAutomaton.build(@parametric_overlaps)
    assert {:error, :overlapping_mappings} = EndpointsAutomaton.build(@double_parametric_overlaps)
  end

  test "parametric endpoints that can overlap for a given parameter choice are marked as overlapping even if the parametric endpoint is the prefix" do
    assert {:error, :overlapping_mappings} =
             EndpointsAutomaton.build(@inverted_parametric_overlaps)
  end

  test "parametric endpoints overlap even when placeholders have different names" do
    assert {:error, :overlapping_mappings} = EndpointsAutomaton.build(@alias_parametric_overlaps)
  end

  test "automaton states depend on both tokens and token position" do
    assert {:ok, automaton} = EndpointsAutomaton.build(@endpoint_similar_tokens)
    assert EndpointsAutomaton.lint(@endpoint_similar_tokens) == []
    assert EndpointsAutomaton.valid?(automaton, @endpoint_similar_tokens) == true
  end

  test "build endpoints automaton and resolve some endpoints" do
    {:ok, params} = Jason.decode(@valid_interface)

    {:ok, document} =
      Interface.changeset(%Interface{}, params)
      |> Ecto.Changeset.apply_action(:insert)

    assert {:ok, automaton} = EndpointsAutomaton.build(document.mappings)
    assert EndpointsAutomaton.valid?(automaton, document.mappings) == true

    assert Enum.count(elem(automaton, 1)) == length(document.mappings)

    # Exact match
    assert EndpointsAutomaton.resolve_path("/filterRules/hello/world/value", automaton) ==
             {:ok, "/filterRules/%{ruleId}/%{filterKey}/value"}

    assert EndpointsAutomaton.resolve_path("/test/0/v", automaton) == {:ok, "/test/%{ind}/v"}

    # Guessed match
    assert EndpointsAutomaton.resolve_path("/filterRules/hello/world", automaton) ==
             {:guessed, ["/filterRules/%{ruleId}/%{filterKey}/value"]}

    assert EndpointsAutomaton.resolve_path("/filterRules/hello/world/", automaton) ==
             {:guessed, ["/filterRules/%{ruleId}/%{filterKey}/value"]}

    assert EndpointsAutomaton.resolve_path("/filterRules/hello", automaton) ==
             {:guessed, ["/filterRules/%{ruleId}/%{filterKey}/value"]}

    assert EndpointsAutomaton.resolve_path("/filterRules", automaton) ==
             {:guessed, ["/filterRules/%{ruleId}/%{filterKey}/value"]}

    assert EndpointsAutomaton.resolve_path("/test/0", automaton) == {:guessed, ["/test/%{ind}/v"]}
    assert EndpointsAutomaton.resolve_path("/test", automaton) == {:guessed, ["/test/%{ind}/v"]}
    assert {:guessed, all_endpoints} = EndpointsAutomaton.resolve_path("", automaton)

    assert Enum.sort(all_endpoints) == [
             "/applicationId",
             "/cmdLine",
             "/filterRules/%{ruleId}/%{filterKey}/value",
             "/message",
             "/monotonicTimestamp",
             "/pid",
             "/test/%{ind}/v",
             "/test2/pluto/v",
             "/timestamp"
           ]

    assert {:guessed, all_endpoints} = EndpointsAutomaton.resolve_path("/", automaton)

    assert Enum.sort(all_endpoints) == [
             "/applicationId",
             "/cmdLine",
             "/filterRules/%{ruleId}/%{filterKey}/value",
             "/message",
             "/monotonicTimestamp",
             "/pid",
             "/test/%{ind}/v",
             "/test2/pluto/v",
             "/timestamp"
           ]
  end

  test "build endpoints automaton and test resolve failure" do
    {:ok, params} = Jason.decode(@valid_interface)

    {:ok, document} =
      Interface.changeset(%Interface{}, params)
      |> Ecto.Changeset.apply_action(:insert)

    assert {:ok, automaton} = EndpointsAutomaton.build(document.mappings)

    assert EndpointsAutomaton.resolve_path("/notFound/hello/world/value", automaton) ==
             {:error, :not_found}

    assert EndpointsAutomaton.resolve_path("/filterRules/hello/world/value/too/long", automaton) ==
             {:error, :not_found}

    assert EndpointsAutomaton.resolve_path("/filterRules/hello/value/other/things", automaton) ==
             {:error, :not_found}
  end

  test "build endpoints automaton and fail due to invalid interface" do
    {:ok, params} = Jason.decode(@invalid_interface)

    {:ok, document} =
      Interface.changeset(%Interface{}, params)
      |> Ecto.Changeset.apply_action(:insert)

    assert {:error, :overlapping_mappings} = EndpointsAutomaton.build(document.mappings)
    assert ["/test/%{ind}/v", "/test/pluto/v"] = EndpointsAutomaton.lint(document.mappings)
  end
end
