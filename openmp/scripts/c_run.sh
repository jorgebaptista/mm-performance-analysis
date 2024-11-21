#!/bin/bash

# ---------------------------------------------------------------------	#
#SBATCH -p hpc
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=96
#SBATCH --mail-type=ALL
#SBATCH --mail-user=a90113@ualg.pt
#SBATCH --job-name=mm-omp-analysis
#SBATCH --output=../logs/cirrus/%j/%x_%j.out
#SBATCH --error=../logs/cirrus/%j/%x_%j.err

# ---------------------------------------------------------------------	#
echo
echo "=== Environment ==="
module purge
module load gcc-13.2

# *******Variables***********
MACHINE=$(hostname)
SESSION_DESCRIPTION="OpenMP Parallelization"
TOTAL_MEM_ALLOC=$((SLURM_JOB_NUM_NODES * SLURM_CPUS_ON_NODE * SLURM_MEM_PER_CPU))

MATRIX_TYPE=${1:-int}
MIN_P=${2:-1}
MAX_P=${3:-10}
NRUNS=30
THREADS= $((SLURM_CPUS_PER_TASK * SLURM_NTASKS_PER_NODE * SLURM_JOB_NUM_NODES))

# ***************************
BIN_DIR="../bin"
DATA_DIR="../../data"
LOGS_DIR="../logs/cirrus/$SLURM_JOB_ID"
RESULTS_DIR="$LOGS_DIR/results"

GENERATE_MATRIX_SOURCE="../../src/generate_matrix.c"
GENERATE_MATRIX_EXE="$BIN_DIR/generate_matrix_$SLURM_JOB_ID"
MULTIPLY_MATRIX_SOURCE="../src/multiply_matrix.c"
LOG_TIMES="$LOGS_DIR/times.log"
RAND_DATA="random_${MATRIX_TYPE}_matrix_${MAX_P}.bin"

mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOGS_DIR" "$RESULTS_DIR"

# *****Generate Matrices******
if ([[ ! -f "$DATA_DIR/$RAND_DATA" ]]) || ([[ " $@ " =~ " -n " ]]); then
    echo "=== Compiling $GENERATE_MATRIX_SOURCE ==="
    gcc -Wall -o "$GENERATE_MATRIX_EXE" "$GENERATE_MATRIX_SOURCE" -DSIZE=$((2 ** $MAX_P)) -DMATRIX_TYPE=$MATRIX_TYPE
    if [ $? -ne 0 ]; then
        echo "Compilation failed."
        exit 1
    fi
    echo "Compilation succeeded."

    echo "=== Running $GENERATE_MATRIX_EXE ==="
    chmod u+x "$GENERATE_MATRIX_EXE"
    ./"$GENERATE_MATRIX_EXE" "$DATA_DIR/$RAND_DATA"
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

# ******Multiply Matrices******
run_matrix_multiplication() {
    local input_file=$1
    local description=$2

    echo "===============================================" | tee -a "$LOG_TIMES"
    echo "Using $description input file:" | tee -a "$LOG_TIMES"

    for ((power = MIN_P; power <= MAX_P; power++)); do
        size=$((2 ** power))

        MULTIPLY_MATRIX_EXE="$BIN_DIR/multiply_matrix_${size}x${size}_$SLURM_JOB_ID"
        LOG_RESULTS="$RESULTS_DIR/${size}x${size}_results.log"
        echo "Matrix product from $description:" >>"$LOG_RESULTS"
        echo "------------${size}x${size}-------------" | tee -a "$LOG_TIMES"

        echo "Compiling multiply_matrix.c"
        rm -f "$MULTIPLY_MATRIX_EXE"
        gcc -fopenmp -o "$MULTIPLY_MATRIX_EXE" "$MULTIPLY_MATRIX_SOURCE" -DSIZE=$size -DMAX_SIZE=$((2 ** $MAX_P)) -DMATRIX_TYPE=$MATRIX_TYPE -DNRUNS=$NRUNS -DTHREADS=$THREADS
        if [ $? -ne 0 ]; then
            echo "Compilation failed."
            break
        fi
        echo "Compilation succeeded."

        echo "Running $MULTIPLY_MATRIX_EXE"
        echo "Nodes: $SLURM_JOB_NUM_NODES" | tee -a "$LOG_TIMES"
        echo "Workers (per node): $SLURM_NTASKS_PER_NODE" | tee -a "$LOG_TIMES"
        echo "CPUs (per task): $SLURM_CPUS_PER_TASK" | tee -a "$LOG_TIMES"

        chmod u+x "$MULTIPLY_MATRIX_EXE"
        /usr/bin/time -v -o "$LOG_TIMES" -a ./"$MULTIPLY_MATRIX_EXE" "$input_file" "$LOG_TIMES" "$LOG_RESULTS"
        if [ $? -ne 0 ]; then
            echo "Execution failed."
            rm -f "$MULTIPLY_MATRIX_EXE"
            break
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
echo "Running $SESSION_DESCRIPTION with $MATRIX_TYPE values on $MACHINE" | tee -a "$LOG_TIMES"
run_matrix_multiplication "$DATA_DIR/$RAND_DATA" "$RAND_DATA"
end_time=$(date +%s)

# *******Finish Session******* #
echo
echo "=== Finalizing ==="
elapsed_seconds=$((end_time - start_time))
elapsed_minutes=$((elapsed_seconds / 60))
remaining_seconds=$((elapsed_seconds % 60))
echo "===============================================" >>"$LOG_TIMES"
echo "Session Time: ${elapsed_minutes}m ${remaining_seconds}s" | tee -a "$LOG_TIMES"
echo "Session Finished at: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_TIMES"
echo "###############################################" >>"$LOG_TIMES"

# *********Log Session******** #
echo "Details for Job ID $SLURM_JOB_ID" >>"$LOG_TIMES"
echo "Running $SESSION_DESCRIPTION with $MATRIX_TYPE values on $MACHINE" >>"$LOG_TIMES"
echo "Allocated Nodes: $SLURM_JOB_NUM_NODES" >>"$LOG_TIMES"
echo "Allocated Workers (per node): $SLURM_NTASKS_PER_NODE" >>"$LOG_TIMES"
echo "Allocated CPUs (per task): $SLURM_CPUS_PER_TASK" >>"$LOG_TIMES"
echo "Allocated Memory (total): $TOTAL_MEM_ALLOC MB" >>"$LOG_TIMES"
echo "Allocated Memory (per node): $SLURM_MEM_PER_NODE MB" >>"$LOG_TIMES"
echo "Allocated Memory (per CPU): $SLURM_MEM_PER_CPU MB" >>"$LOG_TIMES"
echo "=============== Active Modules =================" >>"$LOG_TIMES"
module list 2>&1 | awk NF | sed 's/^/ - /' >>"$LOG_TIMES"
echo "================ Memory Usage ==================" >>"$LOG_TIMES"
sstat -j "${SLURM_JOB_ID}.batch" --format=JobID,MaxRSS,MaxVMSize,MaxDiskRead,MaxDiskWrite >>"$LOG_TIMES"
echo "=============== Nodes Assigned =================" >>"$LOG_TIMES"
scontrol show hostname $SLURM_NODELIST >>"$LOG_TIMES"
echo >>"$LOG_TIMES"

# ***********Exit************ #
exit 0
