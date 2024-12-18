#!/bin/bash

# ---------------------------------------------------------------------	#
#SBATCH -p hpc
#SBATCH --ntasks-per-node=1
#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=a90113@ualg.pt
#SBATCH --job-name=system-specs
#SBATCH --output=../logs/cirrus_specs.log
# ---------------------------------------------------------------------	#

mkdir -p ../logs

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

echo "=== Slurm Partition Information ==="
scontrol show partition
echo ""

echo "=== Slurm Node Information ==="
sinfo -N -l --format="%N %c %m %d %O"
echo ""

echo "=== Node Configuration (Detailed) ==="
scontrol show nodes | grep -E 'NodeName|CPUs|RealMemory|Sockets|CoresPerSocket|ThreadsPerCore|State'
echo ""

echo "=== CPU Information per Node ==="
lscpu | grep -E '^CPU\(s\)|Model name|Thread|Core|Socket|NUMA'
echo ""

echo "==== CPU Information ===="
cat /proc/cpuinfo | grep "model name" | uniq
cat /proc/cpuinfo | grep "cpu cores" | uniq
cat /proc/cpuinfo | grep "siblings" | uniq
echo "========================"

echo "=== Slurm GPU Partition Information ==="
sinfo --format="%P %G %C %m %D"

echo "=== Memory Information ==="
free -h
cat /proc/meminfo
echo ""

echo "=== NUMA Node Information ==="
numactrl --hardware
echo ""

echo "=== Disk Information ==="
df -hT
echo ""

echo "=== Storage Information ==="
lsblk -d -o NAME,ROTA,RO,SIZE,MODEL
echo ""

# Network Information
echo "=== Network Information ==="
ip addr show
echo ""

# SLURM General Configuration
echo ">> SLURM General Configuration"
scontrol show config
echo "SLURM Version:"
sinfo --version
echo ""

# QOS Information
echo ">> SLURM Quality of Service (QOS) Information"
sacctmgr show qos -P
echo ""

# 5. TRES (Trackable Resources) Usage
echo ">> TRES Information"
scontrol show tres
echo ""

# Available Resources
echo "Available Resources (sinfo):"
sinfo -o "%P %D %C %m %G %T"
echo ""
