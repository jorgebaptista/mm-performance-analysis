#include <stdio.h>
#include <sys/time.h>

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
// todo how to define best n?
// todo how are n blocks being assigned, isnt it through job?
#ifndef TILE_WIDTH
#define TILE_WIDTH 32
#endif

typedef MATRIX_TYPE *Matrix;
const int N = SIZE;
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

// todo why isnt matrix A and B const anymore?
__global__ void MatMulKernel(Matrix A, Matrix B, Matrix C)
{
    __shared__ MATRIX_TYPE Ads[TILE_WIDTH][TILE_WIDTH];
    __shared__ MATRIX_TYPE Bds[TILE_WIDTH][TILE_WIDTH];

    int bx = blockIdx.x;
    int by = blockIdx.y;
    int tx = threadIdx.x;
    int ty = threadIdx.y;

    int row = by * TILE_WIDTH + ty;
    int col = bx * TILE_WIDTH + tx;
    MATRIX_TYPE Cval = 0;

    // loop over tiles
    for (int m = 0; m < N / TILE_WIDTH; m++)
    {
        Ads[ty][tx] = A[row * N + m * TILE_WIDTH + tx];
        Bds[ty][tx] = B[(m * TILE_WIDTH + ty) * N + col];
        __syncthreads();

        // loop over elements in tile
        for (int k = 0; k < TILE_WIDTH; k++)
        {
            Cval += Ads[ty][k] * Bds[k][tx];
        }
        __syncthreads();
    }
    C[row * N + col] = Cval; // write to global memory
}

double multiply_matrices(const Matrix A, const Matrix B, Matrix C)
{
    int size = N * N * sizeof(int);
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
    MatMulKernel<<<dGrid, dBlock>>>(Ad, Bd, Cd);
    cudaEventRecord(stopEvent, 0);
    cudaEventSynchronize(stopEvent);

    double milliseconds = 0.0;
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

double read_matrix(FILE *file, Matrix arr, int n, size_t start_element)
{
    gettimeofday(&start, NULL);

    size_t offset = start_element * sizeof(int);
    fseek(file, offset, SEEK_SET);
    fread(arr, sizeof(int), n * n, file);

    gettimeofday(&end, NULL);
    return total_time(start, end);
}

double print_matrix(FILE *file, Matrix C, int n)
{
    gettimeofday(&start, NULL);

    const char *format = (sizeof(n) == sizeof(int)) ? "%d " : "%.2f ";
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n; j++)
        {
            fprintf(file, format, C[i * n + j]);
        }
        fprintf(file, "\n");
    }

    gettimeofday(&end, NULL);
    return total_time(start, end);
}

int main()
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

    for (int i = 0; i <= NRUNS; i++)
    {
        if (i > 0)
            MULT_TIMES[i - 1] = multiply_matrices(A, B, C);
        else
            multiply_matrices(A, B, C); // Warm up
    }

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