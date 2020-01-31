#!/bin/bash
add_individual_datastream=$(./astartectl_linux_amd64 realm-management interfaces install  ./individual_datastreams.org.json --realm-management-url http://localhost:4000/ -r test -k ./test_private.pem)

echo $add_individual_datastream

add_object_streams=$(./astartectl_linux_amd64 realm-management interfaces install  ./object_datastreams.org.json --realm-management-url http://localhost:4000/ -r test -k ./test_private.pem)

echo $add_object_streams

property_streams=$(./astartectl_linux_amd64 realm-management interfaces install  ./properties.org.json --realm-management-url http://localhost:4000/ -r test -k ./test_private.pem)

echo $property_streams
