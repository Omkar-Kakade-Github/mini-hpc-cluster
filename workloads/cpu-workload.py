#!/usr/bin/env python3
"""Deterministic single-process CPU example for Slurm allocations."""
import argparse
import hashlib
import os
import time

parser = argparse.ArgumentParser()
parser.add_argument("--iterations", type=int, default=200000)
args = parser.parse_args()
if args.iterations < 1:
    parser.error("iterations must be positive")

start = time.perf_counter()
digest = b"mini-hpc"
for index in range(args.iterations):
    digest = hashlib.sha256(digest + index.to_bytes(8, "little")).digest()
print(f"host={os.uname().nodename} job={os.getenv('SLURM_JOB_ID', 'none')} "
      f"cpus={os.getenv('SLURM_CPUS_PER_TASK', 'unspecified')} "
      f"iterations={args.iterations} sha256={digest.hex()} "
      f"seconds={time.perf_counter() - start:.3f}", flush=True)
