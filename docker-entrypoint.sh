#!/bin/bash
# Container entrypoint.
#
# Currently runs isolate in rlimit-mode (per-process RLIMIT_AS / RLIMIT_FSIZE
# / RLIMIT_NPROC). The judge0.conf default ENABLE_PER_PROCESS_AND_THREAD_*
# flags = true reflect this.
#
# Switching to isolate's --cg (cgroup v2) mode is a separate work item:
# it requires moving the container's processes into the right cgroup
# layout (Rails workers in a leaf cgroup whose parent has subtree_control
# enabled, isolate sandboxes as children of that parent) AND running
# isolate-cg-keeper to hold the delegation. cgroup v2's "no internal
# process constraint" makes this non-trivial in a non-systemd container.
# Set ENABLE_ISOLATE_CG_MODE=true to opt into the WIP cgroup setup; not
# yet wired up end-to-end.
set -uo pipefail

cron
exec "$@"
