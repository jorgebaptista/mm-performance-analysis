#include <stdio.h>
#include <sys/time.h>
#include <omp.h>

#ifndef SIZE
#define SIZE 1024
#endif

int A[SIZE][SIZE];
int B[SIZE][SIZE];
int C[SIZE][SIZE];

struct timeval start, end;

void read_matrix(FILE *file, int arr[SIZE][SIZE], int n)
{
   for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++)
         fscanf(file, "%d", &arr[i][j]);
}

void print_matrix(FILE *file, int C[SIZE][SIZE], int n)
{
   for (int i = 0; i < n; i++)
   {
      for (int j = 0; j < n; j++)
      {
         fprintf(file, "%d ", C[i][j]);
      }
      fprintf(file, "\n");
   }
}

void multiply_matrices(int A[SIZE][SIZE], int B[SIZE][SIZE], int C[SIZE][SIZE], int n)
{
   int chunk_size = 10; // Adjust based on your performance needs

#pragma omp parallel shared(A, B, C, n, chunk_size)
   {
      int tid = omp_get_thread_num();

// Only one thread prints the starting message
// #pragma omp single
//       {
// printf("Thread %d starting matrix multiply...\n", tid);
//       }

// Parallelize the loop with chunking
#pragma omp for schedule(static, chunk_size)
      for (int i = 0; i < n; i++)
      {
         // printf("Thread=%d did row=%d\n", tid, i);
         for (int j = 0; j < n; j++)
         {
            int sum = 0;
            for (int k = 0; k < n; k++)
            {
               sum += A[i][k] * B[k][j];
            }
            C[i][j] = sum;
         }
      }
   }
}

double calculate_mean(double arr[], int size)
{
   double sum = 0.0;
   for (int i = 0; i < size; i++)
      sum += arr[i];
   return (sum / size);
}

double total_time(struct timeval start, struct timeval end)
{
   return (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
}

int main(int argc, char *argv[])
{
   int n = SIZE;

   const char *matrix_file_name = argv[1];
   const char *time_log_name = argv[2];
   const char *result_log_name = argv[3];

   double results[30] = {0.0};
   const int result_size = 30;
   double read_time = 0.0, multiplication_time = 0.0, mean = 0.0, write_time = 0.0;

   FILE *matrix_file = fopen(matrix_file_name, "r");

   gettimeofday(&start, NULL);
   read_matrix(matrix_file, A, n);
   read_matrix(matrix_file, B, n);
   gettimeofday(&end, NULL);
   read_time = total_time(start, end);
   fclose(matrix_file);

   for (int i = 0; i <= 30; i++)
   {
      gettimeofday(&start, NULL);

      multiply_matrices(A, B, C, n);

      gettimeofday(&end, NULL);
      multiplication_time = total_time(start, end);

      if (i > 0)
         results[i - 1] = multiplication_time;
   }

   mean = calculate_mean(results, result_size);

   FILE *result_log = fopen(result_log_name, "a");
   gettimeofday(&start, NULL);
   print_matrix(result_log, C, n);
   gettimeofday(&end, NULL);
   write_time = total_time(start, end);
   fclose(result_log);

   FILE *time_log = fopen(time_log_name, "a");
   fprintf(time_log, "Read time: %.8f seconds\nMultiplication time (avg): %.8f seconds\nWrite time: %.8f seconds", read_time, mean, write_time);
   fclose(time_log);

   return 0;
}
