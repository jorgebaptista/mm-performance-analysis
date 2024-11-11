#!/bin/bash

# ---------------------------------------------------------------------	#
#SBATCH -p hpc
#SBATCH --ntasks-per-node=1
#SBATCH --nodes=4
#SBATCH --mail-type=ALL
#SBATCH --mail-user=a90113@ualg.pt
#SBATCH --job-name=mm-analysis
#SBATCH --output=../logs/%j/%x_%j.out
#SBATCH --error=../logs/%j/%x_%j.err

# ---------------------------------------------------------------------	#
# todo: still need to fix

echo
echo "=== Environment ==="
module purge
module load gcc13/openmpi/4.1.6

# ***************************
BIN_DIR="../bin"
DATA_DIR="../data"
LOGS_DIR="../logs/$SLURM_JOB_ID"

GENERATE_MATRIX_SOURCE="../src/generate_matrix.c"
GENERATE_MATRIX_EXE="$BIN_DIR/generate_matrix_$SLURM_JOB_ID"
MULTIPLY_MATRIX_SOURCE="../src/multiply_matrix.c"
LOG_TIMES="$LOGS_DIR/times.log"
RAND_DATA="random_matrix_$MAX_P.txt"

mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOGS_DIR"

# ****************************
if ([[ ! -f "$DATA_DIR/$DIAG_DATA" ]] || [[ ! -f "$DATA_DIR/$RAND_DATA" ]]) || ([[ " $@ " =~ " -n " ]]); then
    echo "=== Compiling generate_matrix.c ==="
    gcc -Wall -o "$GENERATE_MATRIX_EXE" "$GENERATE_MATRIX_SOURCE" -DSIZE=1048576
    if [ $? -ne 0 ]; then
        echo "Compilation failed."
        exit 1
    fi
    echo "Compilation succeeded."

    echo "=== Running generate_matrix ==="
    chmod u+x "$GENERATE_MATRIX_EXE"
    ./"$GENERATE_MATRIX_EXE"
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

# ****************************
# sizes=(1 2 3 4 5 6 7 8 9 10)
sizes=(2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576)

run_matrix_multiplication() {
    local input_file=$1
    local description=$2

    echo "=== Initiating tests with $description ==="

    echo "===============================================" >>"$LOG_TIMES"
    echo "Using $description input file:" >>"$LOG_TIMES"

    for size in "${sizes[@]}"; do
        MULTIPLY_MATRIX_EXE="$BIN_DIR/multiply_matrix_${size}x${size}_$SLURM_JOB_ID"

        LOG_RESULTS="$LOGS_DIR/${size}x${size}_results.log"
        echo "Matrix product from $description:" >>"$LOG_RESULTS"
        echo "------------${size}x${size}-------------" | tee -a "$LOG_TIMES"

        echo "Compiling multiply_matrix.c"
        rm -f "$MULTIPLY_MATRIX_EXE"
        mpicc -Wall -o "$MULTIPLY_MATRIX_EXE" "$MULTIPLY_MATRIX_SOURCE" -DSIZE=$size
        if [ $? -ne 0 ]; then
            echo "Compilation failed."
            exit 1
        fi
        echo "Compilation succeeded."

        echo "Running $MULTIPLY_MATRIX_EXE"
        chmod u+x "$MULTIPLY_MATRIX_EXE"
        { time mpiexec -np $SLURM_NTASKS ./"$MULTIPLY_MATRIX_EXE" "$input_file" "$LOG_TIMES" "$LOG_RESULTS"; } 2>>"$LOG_TIMES"
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

    echo "==============================================="
}

#*****************************
start_time=$(date +%s)
echo "Session started at: $(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG_TIMES"
# Run multiply_matrix.c with different args
run_matrix_multiplication "$DATA_DIR/$RAND_DATA" "$RAND_DATA"
run_matrix_multiplication "$DATA_DIR/$DIAG_DATA" "$DIAG_DATA"
end_time=$(date +%s)

# ****************************
echo
echo "=== Finalizing ==="
elapsed_seconds=$((end_time - start_time))
elapsed_minutes=$((elapsed_seconds / 60))
remaining_seconds=$((elapsed_seconds % 60))
echo "Session Completed Successfully at: $(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG_TIMES"
echo "Session Time: ${elapsed_minutes}m ${remaining_seconds}s" | tee -a "$LOG_TIMES"
echo "###############################################" >>"$LOG_TIMES"
echo >>"$LOG_TIMES"
echo "Job Completed Successfully."

# ****************************
exit 0
