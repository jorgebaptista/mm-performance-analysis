#!/bin/bash

# ---------------------------------------------------------------------	#
# Running on fct-deei-linux
# ---------------------------------------------------------------------	#

ID=$(date +%Y%m%d%H%M%S)

# ***************************
BIN_DIR="../bin"
DATA_DIR="../data"
LOGS_DIR="../logs/$ID"

GENERATE_MATRIX_SOURCE="../src/generate_matrix.c"
GENERATE_MATRIX_EXE="$BIN_DIR/generate_matrix_$ID"
MULTIPLY_MATRIX_SOURCE="../src/multiply_matrix.c"
LOG_TIMES="$LOGS_DIR/times.log"
DIAG_DATA="diag_matrix.txt"
RAND_DATA="random_matrix.txt"

mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOGS_DIR"

# ****************************
if ([[ ! -f "$DATA_DIR/$DIAG_DATA" ]] || [[ ! -f "$DATA_DIR/$RAND_DATA" ]]) || ([[ " $@ " =~ " -n " ]]); then
    echo "=== Compiling generate_matrix.c ==="
    gcc -Wall -o "$GENERATE_MATRIX_EXE" "$GENERATE_MATRIX_SOURCE"
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
sizes=(2 2 4 8 16 32 64 128 256 512 1024)

run_matrix_multiplication() {
    local input_file=$1
    local description=$2

    echo "=== Initiating tests with $description ==="

    echo "===============================================" >>"$LOG_TIMES"
    echo "Using $description input file:" >>"$LOG_TIMES"

    for size in "${sizes[@]}"; do
        MULTIPLY_MATRIX_EXE="$BIN_DIR/multiply_matrix_${size}x${size}_$ID"

        LOG_RESULTS="$LOGS_DIR/${size}x${size}_results.log"
        echo "Matrix product from $description:" >>"$LOG_RESULTS"
        echo "------------${size}x${size}-------------" | tee -a "$LOG_TIMES"

        echo "Compiling multiply_matrix.c"
        rm -f "$MULTIPLY_MATRIX_EXE"
        gcc -fopenmp -o "$MULTIPLY_MATRIX_EXE" "$MULTIPLY_MATRIX_SOURCE" -DSIZE=$size
        if [ $? -ne 0 ]; then
            echo "Compilation failed."
            exit 1
        fi
        echo "Compilation succeeded."

        echo "Running $MULTIPLY_MATRIX_EXE"
        chmod u+x "$MULTIPLY_MATRIX_EXE"
        { time ./"$MULTIPLY_MATRIX_EXE" "$input_file" "$LOG_TIMES" "$LOG_RESULTS"; } 2>>"$LOG_TIMES"
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
