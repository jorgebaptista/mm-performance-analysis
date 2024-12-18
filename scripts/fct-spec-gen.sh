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
df -h || echo "df command not found."
echo ""

# Check Connectivity to Remote Server
REMOTE_SERVER="fct-deei-aval"
REMOTE_USER="a90113"

echo "=== Latency to Remote Server ==="
echo "Testing latency to ${REMOTE_SERVER}..."
if ping -c 4 ${REMOTE_SERVER} &>/dev/null; then
    ping -c 4 ${REMOTE_SERVER}
else
    echo "Unable to ping remote-server. Check hostname or network."
fi
echo ""

echo "=== SSH CONNECTIVITY TEST ==="
echo "Testing SSH connectivity to ${REMOTE_USER}@${REMOTE_SERVER}..."
if ssh -o ConnectTimeout=30 ${REMOTE_USER}@${REMOTE_SERVER} 'exit' &>/dev/null; then
    echo "SSH test to ${REMOTE_USER}@${REMOTE_SERVER} successful."
else
    echo "SSH test to ${REMOTE_USER}@${REMOTE_SERVER} failed. Check credentials or network."
fi
echo ""

# Other System Information
echo "=== GPU Information ==="
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi
else
    echo "No NVIDIA GPU detected or 'nvidia-smi' not installed."
fi
echo ""

echo "=== System Uptime and Load ==="
uptime || echo "uptime command not found."
echo ""

# COMPLETION
echo "========================================="
echo "System information collection completed."
exec >/dev/tty 2>&1
echo "System information have been collected in $OUTPUT_FILE." >&2
