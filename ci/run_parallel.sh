#!/usr/bin/env bash
# Run several commands in parallel (one per vCPU on a GitHub runner), each with
# its own log under outputs/logs/, and fail if any of them fails.
# Usage: ci/run_parallel.sh "<log name 1>" "<command 1>" ["<log name 2>" "<command 2>" ...]
set -u
mkdir -p outputs/logs
pids=(); names=()
while [ "$#" -ge 2 ]; do
  name="$1"; cmd="$2"; shift 2
  echo "Starting $name: $cmd"
  bash -c "$cmd" > "outputs/logs/$name.log" 2>&1 &
  pids+=("$!"); names+=("$name")
done
status=0
for k in "${!pids[@]}"; do
  if wait "${pids[$k]}"; then
    echo "Finished ${names[$k]}"
  else
    echo "FAILED ${names[$k]} (see outputs/logs/${names[$k]}.log)"; status=1
  fi
  tail -n 25 "outputs/logs/${names[$k]}.log"
done
exit $status
