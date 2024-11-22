/*****************************************/
/* Using dynamic contiguous  allocation */
/*****************************************/

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <omp.h>

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

MATRIX_TYPE *A;
MATRIX_TYPE *B;
MATRIX_TYPE *C;

double MULT_TIMES[NRUNS];
double THREAD_TIMES[NRUNS][THREADS];
struct timeval start, end;

double total_time(struct timeval start, struct timeval end)
{
   return (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
}

MATRIX_TYPE *allocate_matrix(int n)
{
   MATRIX_TYPE *matrix = malloc(n * n * sizeof(MATRIX_TYPE));
   return matrix;
}

double read_matrix(FILE *file, MATRIX_TYPE *arr, int n, size_t start_element)
{
   gettimeofday(&start, NULL);

   size_t offset = start_element * sizeof(MATRIX_TYPE);
   fseek(file, offset, SEEK_SET);
   fread(arr, sizeof(MATRIX_TYPE), n * n, file);

   gettimeofday(&end, NULL);
   return total_time(start, end);
}

double print_matrix(FILE *file, MATRIX_TYPE *C, int n)
{
   gettimeofday(&start, NULL);

   const char *format = (sizeof(MATRIX_TYPE) == sizeof(int)) ? "%d " : "%.2f ";

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

double multiply_matrices(MATRIX_TYPE *A, MATRIX_TYPE *B, MATRIX_TYPE *C, int n, int nrun)
{
   double mult_start = omp_get_wtime();

#pragma omp parallel shared(A, B, C, n, nrun)
   {
      int tid = omp_get_thread_num();
      double thread_start = omp_get_wtime();

#pragma omp for schedule(static)
      for (int i = 0; i < n; i++)
      {
         for (int j = 0; j < n; j++)
         {
            MATRIX_TYPE sum = 0;
            for (int k = 0; k < n; k++)
            {
               sum += A[i * n + k] * B[k * n + j];
            }
            C[i * n + j] = sum;
         }
      }

      THREAD_TIMES[nrun][tid] = omp_get_wtime() - thread_start;
   }

   return omp_get_wtime() - mult_start;
}

int main(int argc, char *argv[])
{
   const char *matrix_file_name = argv[1];
   const char *time_log_name = argv[2];
   const char *result_log_name = argv[3];

   double read_time = 0.0, write_time = 0.0, avg_multi_times = 0.0,
          avg_thread_times[THREADS] = {0.0};

   omp_set_num_threads(THREADS);

   A = allocate_matrix(SIZE);
   B = allocate_matrix(SIZE);
   C = allocate_matrix(SIZE);

   FILE *matrix_file = fopen(matrix_file_name, "rb");
   read_time = read_matrix(matrix_file, A, SIZE, 0) + read_matrix(matrix_file, B, SIZE, MAX_SIZE * MAX_SIZE);
   fclose(matrix_file);

   for (int i = 0; i <= NRUNS; i++)
   {
      if (i > 0)
         MULT_TIMES[i - 1] = multiply_matrices(A, B, C, SIZE, i - 1);
      else
         multiply_matrices(A, B, C, SIZE, 0); // Warm up
   }

   FILE *result_log = fopen(result_log_name, "a");
   write_time = print_matrix(result_log, C, SIZE);
   fclose(result_log);

   // Calculate average times
   for (int i = 0; i < NRUNS; i++)
   {
      avg_multi_times += MULT_TIMES[i];
      for (int j = 0; j < THREADS; j++)
         avg_thread_times[j] += THREAD_TIMES[i][j];
   }

   avg_multi_times /= NRUNS;
   for (int i = 0; i < THREADS; i++)
      avg_thread_times[i] /= NRUNS;

   FILE *time_log = fopen(time_log_name, "a");
   fprintf(time_log, "Read time: %.8f seconds\nWrite time: %.8f seconds\nMultiplication time (avg): %.8f seconds\n", read_time, write_time, avg_multi_times);
   for (int i = 0; i < THREADS; i++)
      fprintf(time_log, "Thread %d time (avg): %.8f seconds\n", i, avg_thread_times[i]);
   fclose(time_log);

   free(A);
   free(B);
   free(C);

   return 0;
}
