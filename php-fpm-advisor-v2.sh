#!/bin/bash
INPUT_FILE="./input.json"

# Pre-flight checks
command -v jq >/dev/null || { echo "jq is required"; exit 1; }
[[ -f $INPUT_FILE ]] || { echo "$INPUT_FILE not found"; exit 1; }

# Read input
env=$(jq -r '.env' "$INPUT_FILE")
constant_traffic=$(jq -r '.constant_traffic // false' "$INPUT_FILE")
max_active_p95=$(jq -r '.max_active_p95' "$INPUT_FILE")
process_memory_max=$(jq -r '.process_memory_max' "$INPUT_FILE")
cpu_usage_max=$(jq -r '.cpu_usage_max // 0.7' "$INPUT_FILE") # 0-1
served_request_mean=$(jq -r '.served_request_mean // 0' "$INPUT_FILE")
overhead_factor=$(jq -r '.overhead_factor // 1.2' "$INPUT_FILE")
buffer_factor=$(jq -r '.buffer_factor // 1.1' "$INPUT_FILE")

# Validate numeric inputs
for var in max_active_p95 process_memory_max cpu_usage_max served_request_mean overhead_factor buffer_factor; do
  if ! [[ ${!var} =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Invalid value for $var: ${!var}"; exit 1
  fi
done

# Determine PM mode
pm_mode=""
if [[ "$env" == "dev" ]]; then
  pm_mode="ondemand"
elif [[ "$env" == "prod" ]]; then
  [[ "$constant_traffic" == "true" ]] && pm_mode="static" || pm_mode="dynamic"
else
  echo "Invalid env: $env"; exit 1
fi
echo "pm = $pm_mode"

# Calculate max_children considering CPU and memory
estimated_total_memory=$(awk "BEGIN { printf \"%.0f\", $process_memory_max * $max_active_p95 * $overhead_factor * $buffer_factor }")
max_children_memory=$(awk "BEGIN { printf \"%.0f\", $estimated_total_memory / $process_memory_max }")
max_children_cpu=$(awk "BEGIN { printf \"%.0f\", $max_active_p95 / $cpu_usage_max }")
max_children=$(( max_children_memory < max_children_cpu ? max_children_memory : max_children_cpu ))
echo "pm.max_children = $max_children"

# Max requests heuristic
if (( served_request_mean < 10 )); then
  max_requests=200
elif (( served_request_mean < 200 )); then
  max_requests=500
else
  max_requests=1000
fi
echo "pm.max_requests = $max_requests"

# Dynamic extra settings
if [[ "$pm_mode" == "dynamic" ]]; then
  start_servers=$(awk "BEGIN { printf \"%.0f\", $max_children * 0.2 }")
  min_spare_servers=$start_servers
  max_spare_servers=$(awk "BEGIN { printf \"%.0f\", $max_children * 0.3 }")
  [[ $max_spare_servers -gt $max_children ]] && max_spare_servers=$max_children
  echo "pm.start_servers = $start_servers"
  echo "pm.min_spare_servers = $min_spare_servers"
  echo "pm.max_spare_servers = $max_spare_servers"
fi
