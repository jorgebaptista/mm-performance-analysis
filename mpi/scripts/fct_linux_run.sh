#!/bin/bash

# ---------------------------------------------------------------------	#
# Running on fct-deei-linux
# ---------------------------------------------------------------------	#

cd "$(dirname "$0")"

# *******Variables*********** #

ID=$(date +%y-%m-%d-%H%M)
MACHINE="fct-deei-linux"
SESSION_DESCRIPTION="MPI Parallelization"

# Matrix size - 2 to power of P
MIN_P=1
MAX_P=10

# ********Directories********* #
BIN_DIR="../bin"
DATA_DIR="../../shared_data"
LOGS_DIR="../logs/$ID"
RESULTS_DIR="$LOGS_DIR/results"

AVAL_REMOTE="a90113@fct-deei-aval"
AVAL_WD="$(pwd)"
AVAL_BIN_DIR="$(dirname "$AVAL_WD")/bin"

GENERATE_MATRIX_SOURCE="../src/generate_matrix.c"
GENERATE_MATRIX_EXE="$BIN_DIR/generate_matrix_$ID"
MULTIPLY_MATRIX_SOURCE="../src/multiply_matrix.c"
LOG_TIMES="$LOGS_DIR/times.log"
RAND_DATA="random_matrix_$MAX_P.txt"
DIAG_DATA="diag_matrix_$MAX_P.txt"

mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOGS_DIR" "$RESULTS_DIR"
ssh $AVAL_REMOTE "mkdir -p $AVAL_WD"
ssh $AVAL_REMOTE "mkdir -p $AVAL_BIN_DIR"

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

        MULTIPLY_MATRIX_EXE="$BIN_DIR/multiply_matrix_${size}x${size}_$ID"
        LOG_RESULTS="$RESULTS_DIR/${size}x${size}_results.log"
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

        echo "Copying binary to fct-deei-aval"
        scp "$MULTIPLY_MATRIX_EXE" "$AVAL_REMOTE:$AVAL_BIN_DIR"
        if [ $? -ne 0 ]; then
            echo "File transfer to fct-deei-aval failed."
            exit 1
        fi
        echo "File transfer succeeded."

        echo "Running $MULTIPLY_MATRIX_EXE"
        chmod u+x "$MULTIPLY_MATRIX_EXE"
        # { time mpiexec --host fct-deei-linux:4 -np 4 ./"$MULTIPLY_MATRIX_EXE" "$input_file" "$LOG_TIMES" "$LOG_RESULTS"; } 2>>"$LOG_TIMES"
        { time mpiexec --host fct-deei-aval:2,fct-deei-linux:4 -np 6 -wd "$(pwd)" ./"$MULTIPLY_MATRIX_EXE" "$input_file" "$LOG_TIMES" "$LOG_RESULTS"; } 2>>"$LOG_TIMES"
        if [ $? -ne 0 ]; then
            echo "Execution failed."
            rm -f "$MULTIPLY_MATRIX_EXE"
            exit 1
        fi

        echo "Execution succeeded."
        rm -f "$MULTIPLY_MATRIX_EXE"
        ssh $AVAL_REMOTE "rm -f $AVAL_BIN_DIR/$MULTIPLY_MATRIX_EXE"

        echo "===============================================" >>"$LOG_RESULTS"
        echo "Times saved to $LOG_TIMES"
        echo "Results saved to $LOG_RESULTS"
    done
}

# *******Start Session******** #
start_time=$(date +%s)
echo "Session started at: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_TIMES"
echo "Running $SESSION_DESCRIPTION on $MACHINE" | tee -a "$LOG_TIMES"
# Run multiply_matrix.c with different args
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
