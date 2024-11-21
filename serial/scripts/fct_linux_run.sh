#!/bin/bash

# ---------------------------------------------------------------------	#
# Running on fct-deei-linux
# ---------------------------------------------------------------------	#

cd "$(dirname "$0")"

# *******Variables***********
ID=$(date +%y-%m-%d-%H%M)
MACHINE=$(hostname)
SESSION_DESCRIPTION="serial multiplication"

MATRIX_TYPE=${1:-int}
MIN_P=${2:-1}
MAX_P=${3:-10}

# ********Directories*********
BIN_DIR="../bin"
DATA_DIR="../../data"
LOGS_DIR="../logs/fct-deei-linux/$ID"
RESULTS_DIR="$LOGS_DIR/results"

GENERATE_MATRIX_SOURCE="../../src/generate_matrix.c"
GENERATE_MATRIX_EXE="$BIN_DIR/generate_matrix_$ID"
MULTIPLY_MATRIX_SOURCE="../src/multiply_matrix.c"
LOG_TIMES="$LOGS_DIR/times.log"
RAND_DATA="random_${MATRIX_TYPE}_matrix_${MAX_P}.bin"
DIAG_DATA="diag_${MATRIX_TYPE}_matrix_${MAX_P}.bin"

mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOGS_DIR" "$RESULTS_DIR"

# *****Generate Matrices******
if ([[ ! -f "$DATA_DIR/$DIAG_DATA" ]] || [[ ! -f "$DATA_DIR/$RAND_DATA" ]]) || ([[ " $@ " =~ " -n " ]]); then
    echo "=== Compiling $GENERATE_MATRIX_SOURCE ==="
    gcc -Wall -o "$GENERATE_MATRIX_EXE" "$GENERATE_MATRIX_SOURCE" -DSIZE=$((2 ** $MAX_P)) -DMATRIX_TYPE=$MATRIX_TYPE
    if [ $? -ne 0 ]; then
        echo "Compilation failed."
        exit 1
    fi
    echo "Compilation succeeded."

    echo "=== Running $GENERATE_MATRIX_EXE ==="
    chmod u+x "$GENERATE_MATRIX_EXE"
    ./"$GENERATE_MATRIX_EXE" "$DATA_DIR/$RAND_DATA" "$DATA_DIR/$DIAG_DATA"
    if [ $? -ne 0 ]; then
        echo "Execution failed."
        rm -f "$GENERATE_MATRIX_EXE"
        exit 1
    fi
    echo "Execution succeeded."

    rm -f "$GENERATE_MATRIX_EXE"

else
    echo "Using existing input data..."
fi

# *****Multiply Matrices******
run_matrix_multiplication() {
    local input_file=$1
    local description=$2

    echo "===============================================" | tee -a "$LOG_TIMES"
    echo "Using $description input file:" | tee -a "$LOG_TIMES"

    for ((power = MIN_P; power <= MAX_P; power++)); do
        size=$((2 ** power))

        MULTIPLY_MATRIX_EXE="$BIN_DIR/multiply_matrix_${size}x${size}_$ID"
        LOG_RESULTS="$RESULTS_DIR/${size}x${size}_results.log"
        echo "Matrix product from $description:" >>"$LOG_RESULTS"
        echo "------------${size}x${size}-------------" | tee -a "$LOG_TIMES"

        echo "Compiling multiply_matrix.c"
        rm -f "$MULTIPLY_MATRIX_EXE"
        gcc -Wall -o "$MULTIPLY_MATRIX_EXE" "$MULTIPLY_MATRIX_SOURCE" -DSIZE=$size -DMAX_SIZE=$((2 ** $MAX_P)) -DMATRIX_TYPE=$MATRIX_TYPE
        if [ $? -ne 0 ]; then
            echo "Compilation failed."
            exit 1
        fi
        echo "Compilation succeeded."

        echo "Running $MULTIPLY_MATRIX_EXE"
        chmod u+x "$MULTIPLY_MATRIX_EXE"
        { /usr/bin/time -v ./"$MULTIPLY_MATRIX_EXE" "$input_file" "$LOG_TIMES" "$LOG_RESULTS"; } 2>>"$LOG_TIMES"
        if [ $? -ne 0 ]; then
            echo "Execution failed."
            rm -f "$MULTIPLY_MATRIX_EXE"
            exit 1
        fi

        echo "Execution succeeded."
        rm -f "$MULTIPLY_MATRIX_EXE"

        echo "===============================================" >>"$LOG_RESULTS"
        echo "Times saved to $LOG_TIMES"
        echo "Results saved to $LOG_RESULTS"
    done
}

# *******Start Session******** #
start_time=$(date +%s)
echo "Session started at: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_TIMES"

# *****log pre-execution****** #
PRE_MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
PRE_MEM_FREE=$(awk '/MemFree/ {print $2}' /proc/meminfo)
PRE_MEM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
PRE_CPU_STAT=$(cat /proc/stat)

# **********Execute*********** #
echo "Running $SESSION_DESCRIPTION with $MATRIX_TYPE values on $MACHINE" | tee -a "$LOG_TIMES"
run_matrix_multiplication "$DATA_DIR/$RAND_DATA" "$RAND_DATA"
run_matrix_multiplication "$DATA_DIR/$DIAG_DATA" "$DIAG_DATA"
end_time=$(date +%s)

# *******Finish Session******* #
echo
echo "=== Finalizing ==="
elapsed_seconds=$((end_time - start_time))
elapsed_minutes=$((elapsed_seconds / 60))
remaining_seconds=$((elapsed_seconds % 60))
echo "===============================================" >>"$LOG_TIMES"
echo "Session Time: ${elapsed_minutes}m ${remaining_seconds}s" | tee -a "$LOG_TIMES"
echo "Session Completed Successfully at: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_TIMES"
echo "###############################################" >>"$LOG_TIMES"

# *********Log Session******** #
echo "=============== Users on Machine ==============" >>"$LOG_TIMES"
w >>"$LOG_TIMES"
echo "========= Pre-Execution Memory Usage ==========" >>"$LOG_TIMES"
echo "Pre-Execution Memory:" >>"$LOG_TIMES"
echo "  MemTotal: ${PRE_MEM_TOTAL} kB" >>"$LOG_TIMES"
echo "  MemFree: ${PRE_MEM_FREE} kB" >>"$LOG_TIMES"
echo "  MemAvailable: ${PRE_MEM_AVAILABLE} kB" >>"$LOG_TIMES"
echo "========= Post-Execution Memory Usage =========" >>"$LOG_TIMES"
echo "Memory Usage at $(date '+%Y-%m-%d %H:%M:%S'):" >>"$LOG_TIMES"
awk '/MemTotal|MemFree|MemAvailable/ {printf "%s: %s kB\n", $1, $2}' /proc/meminfo >>"$LOG_TIMES"
echo "============== Pre-Execution CPU ==============" >>"$LOG_TIMES"
echo "USER NICE SYSTEM IDLE IOWAIT IRQ SOFTIRQ STEAL GUEST GUEST_NICE" >>"$LOG_TIMES"
echo "$PRE_CPU_STAT" >>$LOG_TIMES
echo "============= Post-Execution CPU ==============" >>"$LOG_TIMES"
echo "USER NICE SYSTEM IDLE IOWAIT IRQ SOFTIRQ STEAL GUEST GUEST_NICE" >>"$LOG_TIMES"
cat /proc/stat >>"$LOG_TIMES"
echo "###############################################" >>"$LOG_TIMES"
echo >>"$LOG_TIMES"

# ***********Exit************ #
exit 0
