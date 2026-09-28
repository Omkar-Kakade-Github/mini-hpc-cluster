#!/usr/bin/env bash
# Run as root on the controller. Uses the real LDAP-backed student account.
set -euo pipefail
student=student1
home=/home/hpc/student1
as_student() { runuser -u "$student" -- bash -c 'cd /home/hpc/student1 && exec "$@"' bash "$@"; }

printf 'test=cpu_affinity\n'
as_student srun -p short --qos=short -N1 -n1 -c1 --mem=128M --time=00:01:00 bash -c 'grep Cpus_allowed_list /proc/self/status'

printf 'test=memory_limit\n'
set +e
memory_result=$(as_student srun -p short --qos=short -N1 -n1 -c1 --mem=128M --time=00:01:00 python3 -c 'x=bytearray(400*1024*1024); print(len(x))' 2>&1)
memory_rc=$?
set -e
printf 'memory_exit=%s\n' "$memory_rc"
printf '%s\n' "$memory_result" | tail -6

printf 'test=queue_saturation\n'
queue_ids=()
for index in 1 2 3 4; do
  queue_ids+=("$(as_student sbatch --parsable -p batch --qos=normal --exclusive -N1 -n1 -c1 --mem=256M --time=00:01:00 --output="$home/queue-%j.out" --wrap='sleep 25')")
done
sleep 4
queue_csv=$(IFS=,; echo "${queue_ids[*]}")
squeue -h -j "$queue_csv" -o '%i|%T|%R' | sort
scancel "$queue_csv"

printf 'test=throughput\n'
start_ns=$(date +%s%N)
job_ids=()
for index in $(seq 1 24); do
  job_ids+=("$(as_student sbatch --parsable -p short --qos=normal -N1 -n1 -c1 --mem=128M --time=00:02:00 --output="$home/benchmark-%j.out" --wrap='/opt/mini-hpc/bin/cpu-workload --iterations 50000')")
done
jobs_csv=$(IFS=,; echo "${job_ids[*]}")
for iteration in $(seq 1 120); do
  if [[ -z $(squeue -h -j "$jobs_csv" -o '%i') ]]; then
    break
  fi
  sleep 1
done
end_ns=$(date +%s%N)
rows=$(sacct -X -n -P -j "$jobs_csv" -o JobID,State)
completed=$(printf '%s\n' "$rows" | awk -F'|' '$2=="COMPLETED" {n++} END {print n+0}')
seconds=$(awk -v a="$start_ns" -v b="$end_ns" 'BEGIN {printf "%.3f", (b-a)/1000000000}')
rate=$(awk -v n="$completed" -v s="$seconds" 'BEGIN {printf "%.2f", n/s}')
printf 'submitted=24 completed=%s elapsed_seconds=%s jobs_per_second=%s\n' "$completed" "$seconds" "$rate"
printf 'states=%s\n' "$(printf '%s\n' "$rows" | awk -F'|' '{n[$2]++} END {for(k in n) printf "%s:%d ",k,n[k]}')"
