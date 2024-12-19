#include <stdio.h>
#include <sys/time.h>
#include <cublas_v2.h>

#ifndef SIZE
#define SIZE 4096
#endif
#ifndef MAX_SIZE
#define MAX_SIZE 4096
#endif
#ifndef NRUNS
#define NRUNS 30
#endif
#ifndef MATRIX_TYPE
#define MATRIX_TYPE int
#endif

typedef MATRIX_TYPE *Matrix;
const size_t N = SIZE;
double MULT_TIMES[NRUNS];
struct timeval start, end;

// CUDA API error checking macro
#define cudaCheck(error)                     \
    if (error != cudaSuccess)                \
    {                                        \
        printf("Fatal error: %s at %s:%d\n", \
               cudaGetErrorString(error),    \
               __FILE__, __LINE__);          \
        exit(1);                             \
    }

double multiply_matrices(const Matrix A, const Matrix B, Matrix C, cublasHandle_t handle)
{
    size_t size = N * N * sizeof(int);
    Matrix Ad, Bd, Cd;
    cudaMalloc(&Ad, size);
    cudaMalloc(&Bd, size);
    cudaMalloc(&Cd, size);

    cudaMemcpy(Ad, A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(Bd, B, size, cudaMemcpyHostToDevice);

    dim3 dBlock(32, 32);
    dim3 dGrid(N / 32, N / 32);

    cudaEvent_t startEvent, stopEvent;
    cudaEventCreate(&startEvent);
    cudaEventCreate(&stopEvent);
    cudaEventRecord(startEvent, 0);

    const MATRIX_TYPE alpha = 1.0;
    const MATRIX_TYPE beta = 0.0;

    if (sizeof(MATRIX_TYPE) == sizeof(double))
    {
        // Double precision
        cublasStatus_t stat = cublasDgemm(
            handle,
            CUBLAS_OP_T, CUBLAS_OP_T,
            N, N, N,
            (const double *)&alpha,
            (const double *)Ad, N,
            (const double *)Bd, N,
            (const double *)&beta,
            (double *)Cd, N);
        if (stat != CUBLAS_STATUS_SUCCESS)
        {
            fprintf(stderr, "cublasDgemm failed\n");
            exit(1);
        }
    }
    else if (sizeof(MATRIX_TYPE) == sizeof(float))
    {
        // Single precision
        cublasStatus_t stat = cublasSgemm(
            handle,
            CUBLAS_OP_T, CUBLAS_OP_T,
            N, N, N,
            (const float *)&alpha,
            (const float *)Ad, N,
            (const float *)Bd, N,
            (const float *)&beta,
            (float *)Cd, N);
        if (stat != CUBLAS_STATUS_SUCCESS)
        {
            fprintf(stderr, "cublasSgemm failed\n");
            exit(1);
        }
    }
    else
    {
        fprintf(stderr, "Unsupported MATRIX_TYPE. Use float or double.\n");
        exit(1);
    }

    cudaEventRecord(stopEvent, 0);
    cudaEventSynchronize(stopEvent);

    float milliseconds = 0.0f;
    cudaEventElapsedTime(&milliseconds, startEvent, stopEvent);

    cudaMemcpy(C, Cd, size, cudaMemcpyDeviceToHost);
    cudaFree(Ad);
    cudaFree(Bd);
    cudaFree(Cd);

    cudaEventDestroy(startEvent);
    cudaEventDestroy(stopEvent);

    return milliseconds / 1000;
}

double total_time(struct timeval start, struct timeval end)
{
    return (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
}

double read_matrix(FILE *file, Matrix arr, size_t n, size_t start_element)
{
    gettimeofday(&start, NULL);

    size_t offset = start_element * sizeof(int);
    fseek(file, offset, SEEK_SET);
    fread(arr, sizeof(int), n * n, file);

    gettimeofday(&end, NULL);
    return total_time(start, end);
}

double print_matrix(FILE *file, Matrix C, size_t n)
{
    gettimeofday(&start, NULL);

    const char *format = (sizeof(n) == sizeof(int)) ? "%d " : "%.2f ";
    for (size_t i = 0; i < n; i++)
    {
        for (size_t j = 0; j < n; j++)
        {
            fprintf(file, format, C[i * n + j]);
        }
        fprintf(file, "\n");
    }

    gettimeofday(&end, NULL);
    return total_time(start, end);
}

int main(int argc, char *argv[])
{
    const char *matrix_file_name = argv[1];
    const char *time_log_name = argv[2];
    const char *result_log_name = argv[3];

    double read_time = 0.0, write_time = 0.0, avg_mult_time = 0.0;

    Matrix A, B, C;
    A = (MATRIX_TYPE *)malloc(N * N * sizeof(MATRIX_TYPE));
    B = (MATRIX_TYPE *)malloc(N * N * sizeof(MATRIX_TYPE));
    C = (MATRIX_TYPE *)malloc(N * N * sizeof(MATRIX_TYPE));

    FILE *matrix_file = fopen(matrix_file_name, "rb");
    read_time = read_matrix(matrix_file, A, N, 0) + read_matrix(matrix_file, B, N, N * N);
    fclose(matrix_file);

    // Initialize cublas
    cublasHandle_t handle;
    cublasCreate(&handle);

    for (int i = 0; i <= NRUNS; i++)
    {
        if (i > 0)
            MULT_TIMES[i - 1] = multiply_matrices(A, B, C, handle);
        else
            multiply_matrices(A, B, C, handle); // Warm up
    }

    cublasDestroy(handle);

    FILE *result_log = fopen(result_log_name, "a");
    write_time = print_matrix(result_log, C, N);
    fclose(result_log);

    for (int i = 0; i < NRUNS; i++)
    {
        avg_mult_time += MULT_TIMES[i];
    }
    avg_mult_time /= NRUNS;

    FILE *time_log = fopen(time_log_name, "a");
    fprintf(time_log, "Read time: %.8f seconds\nWrite time: %.8f seconds\nMultiplication time (avg): %.8f seconds\n", read_time, write_time, avg_mult_time);
    fclose(time_log);

    free(A);
    free(B);
    free(C);

    return 0;
}