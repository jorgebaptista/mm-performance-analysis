#!/usr/bin/env bash
#
# A script to gather system specifications.
#
# This script performs the following tasks:
# 1. Collect CPU and memory information.
# 2. Verify SSH connectivity and ports.
# ##########################################

echo "Running system information collection script..."

# Set output file
mkdir -p ../logs
OUTPUT_FILE="../logs/$(hostname)_specs.log"
exec >"$OUTPUT_FILE" 2>&1

echo "=== SYSTEM INFORMATION REPORT ==="
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

echo "=== CPU INFORMATION ==="
lscpu
echo ""

echo "=== MEMORY INFORMATION ==="
free -h
echo ""

echo "=== Disk Information ==="
df -hT || echo "df command not found."
echo ""

echo "=== Partition Details ==="
lsblk || echo "lsblk command not found."
echo ""

# NETWORK AND CONNECTIVITY

echo "=== Active Network Connections ==="
netstat -tunlp 2>/dev/null || ss -tunlp || echo "Neither netstat nor ss found."
echo ""

echo "=== FIREWALL RULES ==="
if command -v iptables &>/dev/null; then
    # Check firewall rules (ports like 22 for SSH)
    iptables -L -n
else
    echo "iptables command not found. Skipping firewall check."
fi
echo ""

# Check Connectivity to Remote Server

REMOTE_SERVER="fct-deei-aval"
REMOTE_USER="a90113"

echo "=== Latency to remote-server ==="
if ping -c 4 ${REMOTE_SERVER} &>/dev/null; then
    ping -c 4 ${REMOTE_SERVER}
else
    echo "Unable to ping remote-server. Check hostname or network."
fi
echo ""

echo "=== SSH CONNECTIVITY TEST ==="
echo "Testing SSH connectivity with verbose output (no password prompt expected)"
ssh -o BatchMode=yes -o ConnectTimeout=5 -v ${REMOTE_USER}@${REMOTE_SERVER} 'exit' ||
    echo "SSH test to ${REMOTE_USER}@${REMOTE_SERVER} failed. Check credentials or network."
echo ""

# Other

echo "=== PCI Devices ==="
lspci || echo "lspci command not found."
echo ""

echo "=== GPU Information ==="
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi
else
    echo "No NVIDIA GPU detected or 'nvidia-smi' not installed."
fi
echo ""

echo "=== File System Information ==="
mount | grep '^/dev' || echo "No mount points found."
echo ""

echo "=== System Uptime and Load ==="
uptime || echo "uptime command not found."
echo ""

# COMPLETION
exec >/dev/tty 2>&1
echo "System information have been collected in $OUTPUT_FILE." >&2
