#!/bin/bash

./bin/astarte_housekeeping eval Elixir.Astarte.Housekeeping.ReleaseTasks.init_database || exit 1

./bin/astarte_housekeeping eval Elixir.Astarte.Housekeeping.ReleaseTasks.migrate || exit 1

exec ./bin/astarte_housekeeping $@
