#!/bin/bash

# ---------------------------------------------------------------------	#
#SBATCH -p hpc
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=24
#SBATCH --mail-type=ALL
#SBATCH --mail-user=a90113@ualg.pt
#SBATCH --job-name=mm-analysis-hybrid
#SBATCH --output=../logs/slurm/%x_%j.out
#SBATCH --error=../logs/slurm/%x_%j.err

# ---------------------------------------------------------------------	#
echo
echo "=== Environment ==="
module purge
module load gcc13/openmpi/4.1.6

# *******Variables***********
DATE=$(date +%y-%m-%d)
MACHINE="cirrus"
SESSION_DESCRIPTION="Hybrid (MPI + OpenMP) Parallelization"

# Matrix size - 2 to power of P
MIN_P=9
MAX_P=15

THREADS=24

# ********Directories********* #
BIN_DIR="../bin"
DATA_DIR="../../shared_data"
LOGS_DIR="../logs/$SLURM_JOB_ID"
RESULTS_DIR="$LOGS_DIR/results"

GENERATE_MATRIX_SOURCE="../src/generate_matrix.c"
GENERATE_MATRIX_EXE="$BIN_DIR/generate_matrix_$SLURM_JOB_ID"
MULTIPLY_MATRIX_SOURCE="../src/multiply_matrix.c"
LOG_TIMES="$LOGS_DIR/times.log"
RAND_DATA="random_matrix_$MAX_P.txt"

mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOGS_DIR" "$RESULTS_DIR"

# *****Generate Matrices******
if ([[ ! -f "$DATA_DIR/$RAND_DATA" ]]) || ([[ " $@ " =~ " -n " ]]); then
    echo "=== Compiling $GENERATE_MATRIX_SOURCE ==="
    gcc -Wall -o "$GENERATE_MATRIX_EXE" "$GENERATE_MATRIX_SOURCE" -DSIZE=$((2 ** $MAX_P))
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
        mpicc -fopenmp -Wall -o "$MULTIPLY_MATRIX_EXE" "$MULTIPLY_MATRIX_SOURCE" -DSIZE=$size
        if [ $? -ne 0 ]; then
            echo "Compilation failed."
            exit 1
        fi
        echo "Compilation succeeded."

        echo "Running $MULTIPLY_MATRIX_EXE"
        export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
        echo "Nodes: $SLURM_NNODES" | tee -a "$LOG_TIMES"
        echo "Workers: $SLURM_NTASKS_PER_NODE" | tee -a "$LOG_TIMES"
        echo "CPUs: $SLURM_CPUS_PER_TASK" | tee -a "$LOG_TIMES"

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
}

# *******Start Session******** #
start_time=$(date +%s)
echo "Session started at: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_TIMES"
echo "Running $SESSION_DESCRIPTION on $MACHINE" | tee -a "$LOG_TIMES"
echo "Available Nodes: $SLURM_NNODES)" | tee -a "$LOG_TIMES"
echo "Available Workers: $SLURM_NTASKS_PER_NODE)" | tee -a "$LOG_TIMES"
echo "Available CPUs: $SLURM_CPUS_PER_TASK)" | tee -a "$LOG_TIMES"
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
echo "Session Completed Successfully at: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_TIMES"
echo "###############################################" >>"$LOG_TIMES"
echo >>"$LOG_TIMES"

# ***********Exit************ #
exit 0
