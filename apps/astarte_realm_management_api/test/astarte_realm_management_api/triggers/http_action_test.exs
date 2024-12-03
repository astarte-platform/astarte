# Copyright 2020-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.RealmManagement.API.Triggers.HttpActionTest do
  use ExUnit.Case
  alias Astarte.RealmManagement.API.Triggers.HttpAction
  alias Ecto.Changeset

  test "HttpAction is invalid when both http_post_url and http_url are set" do
    input = %{
      "http_post_url" => "http://example.com/post",
      "http_url" => "http://example.com/"
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:http_url] == {"must be blank", []}
    assert length(errors) == 1
  end

  test "HttpAction is invalid when both http_post_url and http_method are set" do
    input = %{
      "http_post_url" => "http://example.com/post",
      "http_method" => "get"
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:http_method] == {"must be blank", []}
    assert length(errors) == 1
  end

  test "HttpAction is invalid when both http_post_url and http_static_headers are set" do
    input = %{
      "http_post_url" => "http://example.com/post",
      "http_static_headers" => %{
        "X-Custom-Header" => "Test",
        "Authorization" => "Bearer foo"
      }
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:http_static_headers] == {"must be blank", []}
    assert length(errors) == 1
  end

  test "http_post_url is translated into http_url and http_method => post" do
    input = %{
      "http_post_url" => "http://example.com/"
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok, %HttpAction{http_url: "http://example.com/", http_method: "post"}} = out
  end

  test "minimal HttpAction with valid http_url and http_method is valid" do
    input = %{
      "http_url" => "http://example.com/",
      "http_method" => "get"
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok, %HttpAction{http_url: "http://example.com/", http_method: "get"}} = out
  end

  test "HttpAction with valid http_url, http_method and http_static_headers is valid" do
    input = %{
      "http_url" => "http://example.com/",
      "http_method" => "put",
      "http_static_headers" => %{
        "X-Custom-Header" => "Test",
        "Authorization" => "Bearer foo"
      }
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    expected_action = %HttpAction{
      http_url: "http://example.com/",
      http_method: "put",
      http_static_headers: %{
        "X-Custom-Header" => "Test",
        "Authorization" => "Bearer foo"
      }
    }

    assert {:ok, expected_action} == out
  end

  test "http_static_headers with non-string values must be rejected" do
    input = %{
      "http_url" => "http://example.com/",
      "http_method" => "put",
      "http_static_headers" => %{
        "X-Custom-Header" => 5,
        "Authorization" => "Bearer foo"
      }
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out

    assert errors[:http_static_headers] ==
             {"is invalid", [{:type, {:map, :string}}, {:validation, :cast}]}

    assert length(errors) == 1
  end

  test "http_static_headers with blocklisted header must be rejected" do
    input = %{
      "http_url" => "http://example.com/",
      "http_method" => "put",
      "http_static_headers" => %{
        "Connection" => "close",
        "Authorization" => "Bearer foo"
      }
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:http_static_headers] == {"must contain only allowed http headers", []}
    assert length(errors) == 1
  end

  test "invalid URL must be rejected" do
    input = %{
      "http_url" => "ftp://example.com/",
      "http_method" => "put"
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out
    assert errors[:http_url] == {"must be a valid http(s) URL", []}
    assert length(errors) == 1
  end

  test "invalid http_method is rejected" do
    input = %{
      "http_url" => "http://example.com/",
      "http_method" => "upgrade"
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:error, %Changeset{errors: errors, valid?: false}} = out

    assert errors[:http_method] ==
             {"is invalid",
              [
                validation: :inclusion,
                enum: ["delete", "get", "head", "options", "patch", "post", "put"]
              ]}

    assert length(errors) == 1
  end

  test "ignore_ssl_errors is set" do
    input = %{
      "http_url" => "http://example.com/",
      "http_method" => "get",
      "ignore_ssl_errors" => true
    }

    out =
      %HttpAction{}
      |> HttpAction.changeset(input)
      |> Changeset.apply_action(:insert)

    assert {:ok,
            %HttpAction{
              http_url: "http://example.com/",
              http_method: "get",
              ignore_ssl_errors: true
            }} = out
  end
end
