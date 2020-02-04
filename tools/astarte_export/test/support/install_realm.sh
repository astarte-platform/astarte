#!/bin/bash
add_test_realm_result=$(./astartectl_linux_amd64 housekeeping realms create test --housekeeping-url http://localhost:4001/ -p ./test_public.pem -k ./housekeeping_private.pem)
echo $add_test_realm_result
