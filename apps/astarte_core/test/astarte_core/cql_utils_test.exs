defmodule CQLUtilsTest do
  use ExUnit.Case
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Realm

  test "interface name to table name" do
    assert CQLUtils.interface_name_to_table_name("com.ispirata.Hemera.DeviceLog", 1) ==
             "com_ispirata_hemera_devicelog_v1"

    assert CQLUtils.interface_name_to_table_name("test", 0) == "test_v0"
  end

  test "endpoint name to object interface column name" do
    assert CQLUtils.endpoint_to_db_column_name("/testEndpoint") == "v_testendpoint"
    assert CQLUtils.endpoint_to_db_column_name("%{p0}/%{p1}/testEndpoint2") == "v_testendpoint2"

    assert CQLUtils.endpoint_to_db_column_name("/this_is_a_quite_long_endpoint_name_thatis43") ==
             "v_this_is_a_quite_long_endpoint_name_thatis43"

    assert CQLUtils.endpoint_to_db_column_name("/this_is_a_quite_long_endpoint_name_that_is44") ==
             "v_1XOzAu_s_a_quite_long_endpoint_name_that_is44"

    assert CQLUtils.endpoint_to_db_column_name(
             "/this_is_a_quite_long_endpoint_name_that_is_more_than_characters_48"
           ) == "v_o82S8J_t_name_that_is_more_than_characters_48"
  end

  test "is valid CQL name" do
    assert CQLUtils.is_valid_cql_name?("0I_II_II_L") == false
    assert CQLUtils.is_valid_cql_name?("I_II_II_L_0") == true
    assert CQLUtils.is_valid_cql_name?("I_II_II_L_ù") == false
    assert CQLUtils.is_valid_cql_name?("ù_I_II_II_L") == false
    assert CQLUtils.is_valid_cql_name?("_I_II_II_L_ù") == false
    assert CQLUtils.is_valid_cql_name?("") == false
    assert CQLUtils.is_valid_cql_name?("v_testendpoint") == true
    assert CQLUtils.is_valid_cql_name?("v_testendpoint2") == true
    assert CQLUtils.is_valid_cql_name?("v_this_is_a_quite_long_endpoint_name_thatis43") == true
    assert CQLUtils.is_valid_cql_name?("v_1XOzAu_s_a_quite_long_endpoint_name_that_is44") == true
    assert CQLUtils.is_valid_cql_name?("v_o82S8J_t_name_that_is_more_than_characters_48") == true
    assert CQLUtils.is_valid_cql_name?("v_o82S8J_t_name_that_is_more_than_characters_48a") == true

    assert CQLUtils.is_valid_cql_name?("v_o82S8J_t_name_that_is_more_than_characters_48ab") ==
             false
  end

  test "mapping value type to db column type" do
    assert CQLUtils.mapping_value_type_to_db_type(:double) == "double"
    assert CQLUtils.mapping_value_type_to_db_type(:integer) == "int"
    assert CQLUtils.mapping_value_type_to_db_type(:boolean) == "boolean"
    assert CQLUtils.mapping_value_type_to_db_type(:longinteger) == "bigint"
    assert CQLUtils.mapping_value_type_to_db_type(:string) == "varchar"
    assert CQLUtils.mapping_value_type_to_db_type(:binaryblob) == "blob"
    assert CQLUtils.mapping_value_type_to_db_type(:datetime) == "timestamp"
    assert CQLUtils.mapping_value_type_to_db_type(:doublearray) == "list<double>"
    assert CQLUtils.mapping_value_type_to_db_type(:integerarray) == "list<int>"
    assert CQLUtils.mapping_value_type_to_db_type(:booleanarray) == "list<boolean>"
    assert CQLUtils.mapping_value_type_to_db_type(:longintegerarray) == "list<bigint>"
    assert CQLUtils.mapping_value_type_to_db_type(:stringarray) == "list<varchar>"
    assert CQLUtils.mapping_value_type_to_db_type(:binaryblobarray) == "list<blob>"
    assert CQLUtils.mapping_value_type_to_db_type(:datetimearray) == "list<timestamp>"

    assert_raise CaseClauseError, fn -> CQLUtils.mapping_value_type_to_db_type("integer") end
    assert_raise CaseClauseError, fn -> CQLUtils.mapping_value_type_to_db_type(:date) end
    assert_raise CaseClauseError, fn -> CQLUtils.mapping_value_type_to_db_type(:time) end
    assert_raise CaseClauseError, fn -> CQLUtils.mapping_value_type_to_db_type(:int64) end
    assert_raise CaseClauseError, fn -> CQLUtils.mapping_value_type_to_db_type(:timestamp) end
    assert_raise CaseClauseError, fn -> CQLUtils.mapping_value_type_to_db_type(:float) end
  end

  test "mapping value type to individual interface column name" do
    assert CQLUtils.type_to_db_column_name(:double) == "double_value"
    assert CQLUtils.type_to_db_column_name(:integer) == "integer_value"
    assert CQLUtils.type_to_db_column_name(:boolean) == "boolean_value"
    assert CQLUtils.type_to_db_column_name(:longinteger) == "longinteger_value"
    assert CQLUtils.type_to_db_column_name(:string) == "string_value"
    assert CQLUtils.type_to_db_column_name(:binaryblob) == "binaryblob_value"
    assert CQLUtils.type_to_db_column_name(:datetime) == "datetime_value"
    assert CQLUtils.type_to_db_column_name(:doublearray) == "doublearray_value"
    assert CQLUtils.type_to_db_column_name(:integerarray) == "integerarray_value"
    assert CQLUtils.type_to_db_column_name(:booleanarray) == "booleanarray_value"
    assert CQLUtils.type_to_db_column_name(:longintegerarray) == "longintegerarray_value"
    assert CQLUtils.type_to_db_column_name(:stringarray) == "stringarray_value"
    assert CQLUtils.type_to_db_column_name(:binaryblobarray) == "binaryblobarray_value"
    assert CQLUtils.type_to_db_column_name(:datetimearray) == "datetimearray_value"

    assert_raise CaseClauseError, fn -> CQLUtils.type_to_db_column_name("integer") end
    assert_raise CaseClauseError, fn -> CQLUtils.type_to_db_column_name(:date) end
    assert_raise CaseClauseError, fn -> CQLUtils.type_to_db_column_name(:time) end
    assert_raise CaseClauseError, fn -> CQLUtils.type_to_db_column_name(:int64) end
    assert_raise CaseClauseError, fn -> CQLUtils.type_to_db_column_name(:timestamp) end
    assert_raise CaseClauseError, fn -> CQLUtils.type_to_db_column_name(:float) end
  end

  test "interface id generation" do
    assert CQLUtils.interface_id("com.foo", 2) == CQLUtils.interface_id("com.foo", 2)
    assert CQLUtils.interface_id("com.test", 0) != CQLUtils.interface_id("com.test", 1)
    assert CQLUtils.interface_id("com.test1", 0) != CQLUtils.interface_id("com.test", 10)
    assert CQLUtils.interface_id("a", 1) != CQLUtils.interface_id("b", 1)

    assert CQLUtils.interface_id("org.astarte-platform.MyInterface", 1) !=
             CQLUtils.interface_id("org.astarte-platform.myinterface", 1)

    assert CQLUtils.interface_id("This.Is.A.Test", 1) !=
             CQLUtils.interface_id("this.is.a.test", 1)

    assert CQLUtils.interface_id("org.astarte-platform.MyInterface", 1) !=
             CQLUtils.interface_id("org.astarte-platform.MyInterface", 0)

    assert CQLUtils.interface_id("astarte.is.cool", 10) ==
             <<209, 245, 26, 90, 177, 111, 236, 137, 134, 53, 237, 97, 134, 247, 21, 254>>
  end

  test "endpoint id generation" do
    assert CQLUtils.endpoint_id("com.foo", 2, "/test/foo") ==
             CQLUtils.endpoint_id("com.foo", 2, "/test/foo")

    assert CQLUtils.endpoint_id("com.foo", 2, "/test/Foo") !=
             CQLUtils.endpoint_id("com.foo", 2, "/test/foo")

    assert CQLUtils.endpoint_id("org.astarte-platform.MyInterface", 0, "/test/foo") !=
             CQLUtils.endpoint_id("org.astarte-platform.myinterface", 0, "/test/foo")

    assert CQLUtils.endpoint_id("Test", 10, "/test") !=
             CQLUtils.endpoint_id("test", 10, "/test")

    assert CQLUtils.endpoint_id("com.foo", 2, "/test/foo") !=
             CQLUtils.endpoint_id("com.foo", 3, "/test/foo")

    assert CQLUtils.endpoint_id("com.foo", 1, "/test/foo") !=
             CQLUtils.endpoint_id("com.bar", 1, "/test/foo")

    assert CQLUtils.endpoint_id("com.foo", 1, "/test/foo") ==
             <<47, 163, 1, 227, 139, 231, 222, 201, 41, 57, 24, 82, 234, 76, 61, 4>>
  end

  test "endpoint id generation with normalization" do
    assert CQLUtils.endpoint_id("com.foo", 2, "/a/%{something}") ==
             CQLUtils.endpoint_id("com.foo", 2, "/a/%{different}")

    assert CQLUtils.endpoint_id("com.foo", 2, "/a/%{something}") ==
             CQLUtils.endpoint_id("com.foo", 2, "/a/%{SomeThing}")

    assert CQLUtils.endpoint_id("com.foo", 2, "/a/%{something}") !=
             CQLUtils.endpoint_id("com.foo", 2, "/b/%{SomeThing}")

    assert CQLUtils.endpoint_id("com.foo", 10, "/a/%{something}/foo") ==
             CQLUtils.endpoint_id("com.foo", 10, "/a//foo")

    assert CQLUtils.endpoint_id("com.foo", 2, "/a/%{something}/foo") !=
             CQLUtils.endpoint_id("com.foo", 2, "/a/%{something}/bar")
  end

  describe "Realm name to keyspace name translation" do
    test "works with a short realm name that does not get encoded" do
      assert CQLUtils.realm_name_to_keyspace_name("example", "atestinstance") ==
               "atestinstanceexample"

      assert Realm.valid_name?(CQLUtils.realm_name_to_keyspace_name("example", "atestinstance")) ==
               true
    end

    test "works with a long realm name that does get encoded" do
      assert CQLUtils.realm_name_to_keyspace_name(
               "averyveryverylongrealmnamejustforthistest",
               "atestinstance"
             ) ==
               "yxrlc3rpbnn0yw5jzwf2zxj5dmvyexzlcnlsb25ncmvhbg1u"

      assert Realm.valid_name?(
               CQLUtils.realm_name_to_keyspace_name(
                 "averyveryverylongrealmnamejustforthistest",
                 "atestinstance"
               )
             ) == true
    end
  end
end
