#!/bin/bash

# ---------------------------------------------------------------------	#
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:1
#SBATCH --ntasks-per-node=1
#SBATCH --time=00:01:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=a90113@ualg.pt
#SBATCH --qos=gpuvlabualg
#SBATCH --job-name=system-specs
#SBATCH --output=../logs/cirrus_specs.log
# ---------------------------------------------------------------------	#

module purge
module load cuda/12.6

mkdir -p ../logs
mkdir -p ../bin

echo ""
echo "=== SYSTEM INFORMATION REPORT ==="
echo "Partition: $SLURM_JOB_PARTITION"
echo "Current Working Directory: $(pwd)"
echo "Report generated on: $(date)"
echo ""

echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Operating System: $(uname -s)"
echo "Kernel Version: $(uname -r)"
echo "Architecture: $(uname -m)"
if [ -f /etc/os-release ]; then
    echo "Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
fi
echo ""

echo "==== Gathering GPU specs for all GPUs on the node ===="
nvidia-smi --query-gpu=name,memory.total,clocks.max.graphics,clocks.max.sm,compute_mode --format=csv
echo ""

echo "==== CUDA Detailed GPU Info ===="
nvcc ../src/gpu_info.cu -o ../bin/gpu_info
../bin/gpu_info
echo ""

echo "=== CPU Information per Node ==="
lscpu | grep -E '^CPU\(s\)|Model name|Thread|Core|Socket|NUMA'
echo ""

echo "=== Memory Information ==="
cat /proc/meminfo | awk '/MemTotal|SwapTotal|PageTables|MemFree|Buffers|Cached|HugePages_Total|HugePages_Free/ {printf "%-16s: %10d MB\n", $1, $2 / 1024}'
echo ""

echo "=== Slurm Partition Information ==="
scontrol show partition | awk '/PartitionName=hpc|PartitionName=gpu/,/^$/' | \
grep -E "PartitionName=|Nodes=|State=|DefMemPerCPU=|TRES="
echo ""

echo "==== Available Resources (sinfo) ===="
sinfo -o "%P %D %C %m %G %T"
echo ""

echo "=== Disk Information ==="
df -hT
echo ""

echo "=== Storage Information ==="
lsblk -d -o NAME,ROTA,RO,SIZE,MODEL
echo ""

echo "SLURM Version:"
sinfo --version
echo ""
