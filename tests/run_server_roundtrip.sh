#!/usr/bin/env bash
set -u

godot --headless --path . --scene res://tests/ServerRoundtripTest.tscn -- --role=server &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT

sleep 1
godot --headless --path . --scene res://tests/ServerRoundtripTest.tscn -- --role=client
client_status=$?

wait "$server_pid"
server_status=$?
trap - EXIT

if [[ $client_status -ne 0 || $server_status -ne 0 ]]; then
	exit 1
fi
