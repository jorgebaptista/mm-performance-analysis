/*****************************************************/
/*    This program multiplies two square matrices    */
/*            using OpenMP parallelization           */
/*            with static matrix allocation          */
/*        reading from a binary input file           */
/*                   using BlLAS                     */
/*****************************************************/

#include <stdio.h>
#include <sys/time.h>
#include <omp.h>
#include <cblas.h>

#ifndef SIZE
#define SIZE 1024
#endif
#ifndef MAX_SIZE
#define MAX_SIZE 1024
#endif
#ifndef NRUNS
#define NRUNS 30
#endif
#ifndef MATRIX_TYPE
#define MATRIX_TYPE int
#endif
#ifndef THREADS
#define THREADS 4
#endif

MATRIX_TYPE A[SIZE][SIZE];
MATRIX_TYPE B[SIZE][SIZE];
MATRIX_TYPE C[SIZE][SIZE];

struct timeval start, end;

double total_time(struct timeval start, struct timeval end)
{
   return (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
}

double read_matrix(FILE *file, MATRIX_TYPE arr[SIZE][SIZE], int n, int start_element)
{
   gettimeofday(&start, NULL);

   long offset = start_element * sizeof(MATRIX_TYPE);
   fseek(file, offset, SEEK_SET);
   fread(arr[0], sizeof(MATRIX_TYPE), n * n, file);

   gettimeofday(&end, NULL);
   return total_time(start, end);
}

double print_matrix(FILE *file, MATRIX_TYPE C[SIZE][SIZE], int n)
{
   gettimeofday(&start, NULL);

   const char *format = (sizeof(MATRIX_TYPE) == sizeof(int)) ? "%d " : "%.2f ";

   for (int i = 0; i < n; i++)
   {
      for (int j = 0; j < n; j++)
      {
         fprintf(file, format, C[i][j]);
      }
      fprintf(file, "\n");
   }

   gettimeofday(&end, NULL);
   return total_time(start, end);
}

double multiply_matrices(MATRIX_TYPE A[SIZE][SIZE], MATRIX_TYPE B[SIZE][SIZE], MATRIX_TYPE C[SIZE][SIZE], int n, int nrun)
{
   double mult_start = omp_get_wtime();

   if (sizeof(MATRIX_TYPE) == sizeof(double))
   {
      // Double-precision BLAS
      cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                  n, n, n,
                  1.0,
                  A[0], n,
                  B[0], n,
                  0.0,
                  C[0], n);
   }
   else if (sizeof(MATRIX_TYPE) == sizeof(float))
   {
      // Single-precision BLAS
      cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                  n, n, n,
                  1.0f,
                  (float *)A[0], n,
                  (float *)B[0], n,
                  0.0f,
                  (float *)C[0], n);
   }

   return omp_get_wtime() - mult_start;
}

int main(int argc, char *argv[])
{
   const char *matrix_file_name = argv[1];
   const char *time_log_name = argv[2];
   const char *result_log_name = argv[3];

   double read_time = 0.0, write_time = 0.0, avg_multi_times = 0.0;

   omp_set_num_threads(THREADS);
   openblas_set_num_threads(THREADS);

   FILE *matrix_file = fopen(matrix_file_name, "rb");
   read_time = read_matrix(matrix_file, A, SIZE, 0) + read_matrix(matrix_file, B, SIZE, MAX_SIZE * MAX_SIZE);
   fclose(matrix_file);

   for (int i = 0; i <= NRUNS; i++)
   {
      if (i > 0)
         avg_multi_times += multiply_matrices(A, B, C, SIZE, i - 1);
      else
         multiply_matrices(A, B, C, SIZE, 0); // Warm up
   }

   FILE *result_log = fopen(result_log_name, "a");
   write_time = print_matrix(result_log, C, SIZE);
   fclose(result_log);

   avg_multi_times /= NRUNS;

   FILE *time_log = fopen(time_log_name, "a");
   fprintf(time_log, "Read time: %.8f seconds\nWrite time: %.8f seconds\nMultiplication time (avg): %.8f seconds\n", read_time, write_time, avg_multi_times);
   fclose(time_log);

   return 0;
}
