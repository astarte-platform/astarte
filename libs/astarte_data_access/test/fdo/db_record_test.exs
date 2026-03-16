#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.FDO.OwnershipVoucher.DBRecordTest do
  use ExUnit.Case, async: true

  alias Astarte.DataAccess.FDO.OwnershipVoucher

  @valid_attrs %{
    guid: :crypto.strong_rand_bytes(16),
    voucher_data: :crypto.strong_rand_bytes(64),
    private_key: :crypto.strong_rand_bytes(32)
  }

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      changeset = OwnershipVoucher.changeset(%OwnershipVoucher{}, @valid_attrs)

      assert changeset.valid?
    end

    test "is invalid when guid is missing" do
      attrs = Map.delete(@valid_attrs, :guid)
      changeset = OwnershipVoucher.changeset(%OwnershipVoucher{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :guid)
    end

    test "is invalid when voucher_data is missing" do
      attrs = Map.delete(@valid_attrs, :voucher_data)
      changeset = OwnershipVoucher.changeset(%OwnershipVoucher{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :voucher_data)
    end

    test "is invalid when private_key is missing" do
      attrs = Map.delete(@valid_attrs, :private_key)
      changeset = OwnershipVoucher.changeset(%OwnershipVoucher{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :private_key)
    end

    test "applies changes when valid" do
      changeset = OwnershipVoucher.changeset(%OwnershipVoucher{}, @valid_attrs)

      assert changeset.changes.voucher_data == @valid_attrs.voucher_data
      assert changeset.changes.private_key == @valid_attrs.private_key
    end
  end
end
