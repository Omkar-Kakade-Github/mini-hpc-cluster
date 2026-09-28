#!/bin/bash
#SBATCH --job-name=cpu-short
#SBATCH --partition=short
#SBATCH --qos=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=256M
#SBATCH --time=00:02:00
#SBATCH --output=slurm-%j.out
set -euo pipefail
source /etc/profile.d/modules.sh
module load mini-hpc/1.0
srun cpu-workload --iterations 200000
