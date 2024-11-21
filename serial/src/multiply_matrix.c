#include <stdio.h>
#include <sys/time.h>

#ifndef SIZE
#define SIZE 1024
#endif
#ifndef NRUNS
#define NRUNS 30
#endif
#ifndef MATRIX_TYPE
#define MATRIX_TYPE int
#endif

MATRIX_TYPE A[SIZE][SIZE];
MATRIX_TYPE B[SIZE][SIZE];
MATRIX_TYPE C[SIZE][SIZE];

double MULT_TIMES[NRUNS];
struct timeval start, end;

double total_time(struct timeval start, struct timeval end)
{
   return (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
}

double read_matrix(FILE *file, MATRIX_TYPE arr[SIZE][SIZE], int n, int offset)
{
   gettimeofday(&start, NULL);

   for (int i = 0; i < n; i++)
      for (int j = offset; j < n + offset; j++)
         fscanf(file, "%d", &arr[i][j]);

   gettimeofday(&end, NULL);
   return total_time(start, end);
}

double print_matrix(FILE *file, MATRIX_TYPE C[SIZE][SIZE], int n)
{
   gettimeofday(&start, NULL);

   for (int i = 0; i < n; i++)
   {
      for (int j = 0; j < n; j++)
      {
         fprintf(file, "%d ", C[i][j]);
      }
      fprintf(file, "\n");
   }

   gettimeofday(&end, NULL);
   return total_time(start, end);
}

double multiply_matrices(MATRIX_TYPE A[SIZE][SIZE], MATRIX_TYPE B[SIZE][SIZE], MATRIX_TYPE C[SIZE][SIZE], int n)
{
   gettimeofday(&start, NULL);

   for (int i = 0; i < n; i++)
   {
      for (int j = 0; j < n; j++)
      {
         MATRIX_TYPE sum = 0;
         for (int k = 0; k < n; k++)
         {
            sum += A[i][k] * B[k][j];
         }
         C[i][j] = sum;
      }
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

   FILE *matrix_file = fopen(matrix_file_name, "r");
   read_time = read_matrix(matrix_file, A, SIZE, 0) + read_matrix(matrix_file, B, SIZE, SIZE);
   fclose(matrix_file);

   for (int i = 0; i <= NRUNS; i++)
   {
      if (i > 0)
         MULT_TIMES[i - 1] = multiply_matrices(A, B, C, SIZE);
      else
         multiply_matrices(A, B, C, SIZE); // Warm up
   }

   FILE *result_log = fopen(result_log_name, "a");
   write_time = print_matrix(result_log, C, SIZE);
   fclose(result_log);

   // Calculate average times
   for (int i = 0; i < NRUNS; i++)
      avg_mult_time += MULT_TIMES[i];

   avg_mult_time /= NRUNS;

   FILE *time_log = fopen(time_log_name, "a");
   fprintf(time_log, "Read time: %.8f seconds\nWrite time: %.8f seconds\nMultiplication time (avg): %.8f seconds\n", read_time, write_time, avg_mult_time);
   fclose(time_log);

   return 0;
}
