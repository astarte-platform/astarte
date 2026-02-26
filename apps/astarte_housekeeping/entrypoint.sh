#!/bin/bash

set -e

./bin/astarte_housekeeping eval Elixir.Astarte.Housekeeping.ReleaseTasks.init_database
./bin/astarte_housekeeping eval Elixir.Astarte.Housekeeping.ReleaseTasks.migrate

exec ./bin/astarte_housekeeping $@
