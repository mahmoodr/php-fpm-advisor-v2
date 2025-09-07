# PHP-FPM Advisor Script

A metrics-driven tool to recommend right-sized PHP-FPM configurations based on historical usage patterns.

Inspired by [Hatam's medium post](https://medium.com/@hatamabolghasemi/how-i-reduced-php-fpm-based-backend-stack-memory-utilization-by-over-80-without-changing-a-line-a22dd983c6ea) on reducing memory usage without touching application code. This v2 version adds safety buffers, CPU consideration, percentile-based analysis, and staging validation recommendations.

Also see [my medium post](https://rome-rohani.medium.com/optimizing-php-fpm-metrics-driven-right-sizing-374b5aefbf08) for a detailed walkthrough of this approach.

## Features

- Calculates `pm`, `pm.max_children`, `pm.max_requests`, and dynamic pool settings.
- Supports configurable memory overhead and burst buffers.
- Uses historical p95 metrics for active PHP-FPM processes.
- Compatible with staging validation and Kubernetes horizontal scaling.

## Requirements

- Bash
- `jq` command-line JSON processor

## Usage

1. Prepare `input.json` with metrics:

```json
{
  "env": "prod",
  "constant_traffic": false,
  "max_active_p95": 50,
  "process_memory_max": 64,
  "cpu_usage_max": 0.7,
  "served_request_mean": 150,
  "overhead_factor": 1.2,
  "buffer_factor": 1.1
}
