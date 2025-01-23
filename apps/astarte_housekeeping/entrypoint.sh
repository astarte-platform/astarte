#!/bin/bash

# Copyright 2019-2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

set -e

./astarte-service eval Elixir.Astarte.Housekeeping.ReleaseTasks.init_database
./astarte-service eval Elixir.Astarte.Housekeeping.ReleaseTasks.migrate

exec $@
