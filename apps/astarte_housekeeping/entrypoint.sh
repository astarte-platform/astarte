#!/bin/bash
set -e

./astarte-service eval Elixir.Astarte.Housekeeping.ReleaseTasks.init_database
./astarte-service eval Elixir.Astarte.Housekeeping.ReleaseTasks.migrate

exec $@
