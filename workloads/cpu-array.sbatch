#!/bin/bash
#SBATCH --job-name=cpu-array
#SBATCH --partition=batch
#SBATCH --qos=normal
#SBATCH --array=0-5%3
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=256M
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%A_%a.out
set -euo pipefail
source /etc/profile.d/modules.sh
module load mini-hpc/1.0
srun cpu-workload --iterations $((150000 + SLURM_ARRAY_TASK_ID * 10000))
