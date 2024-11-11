#include <stdio.h>
#include <stdlib.h>
#include "mpi.h"
#include <omp.h>

#ifndef SIZE
#define SIZE 1024
#endif

#define MASTER 0
#define FROM_MASTER 1
#define FROM_WORKER 2
#define START_MULTIPLY 3
#define STOP_WORKERS 4

int A[SIZE][SIZE];
int B[SIZE][SIZE];
int C[SIZE][SIZE];

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

void multiply_matrices(int A[SIZE][SIZE], int B[SIZE][SIZE], int C[SIZE][SIZE], int rows, int n)
{
#pragma omp parallel for collapse(2)
   for (int i = 0; i < rows; i++)
   {
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

double calculate_mean(double arr[], int size)
{
   double sum = 0.0;
   for (int i = 0; i < size; i++)
      sum += arr[i];
   return (sum / size);
}

int main(int argc, char *argv[])
{
   int numtasks, taskid, numworkers, source, dest, mtype, averow, extra, offset, rows;
   MPI_Status status;

   int n = SIZE;
   double results[30] = {0.0};
   const int result_size = 30;
   double start_time, end_time;
   double read_time = 0.0, multiplication_time = 0.0, mean = 0.0, write_time = 0.0;

   MPI_Init(&argc, &argv);
   MPI_Comm_rank(MPI_COMM_WORLD, &taskid);
   MPI_Comm_size(MPI_COMM_WORLD, &numtasks);
   if (numtasks < 2)
   {
      printf("Need at least two MPI tasks. Quitting...\n");
      MPI_Abort(MPI_COMM_WORLD, 0);
      exit(1);
   }
   numworkers = numtasks - 1;

   /**************************** Master Task ************************************/
   if (taskid == MASTER)
   {
      // todo error checking?
      const char *matrix_file_name = argv[1];
      const char *time_log_name = argv[2];
      const char *result_log_name = argv[3];

      FILE *matrix_file = fopen(matrix_file_name, "r");

      // read input
      start_time = MPI_Wtime();
      read_matrix(matrix_file, A, n);
      read_matrix(matrix_file, B, n);
      end_time = MPI_Wtime();
      read_time = end_time - start_time;
      fclose(matrix_file);

      // send matrix data to workers
      averow = n / numworkers;
      extra = n % numworkers;
      offset = 0;
      mtype = FROM_MASTER;

      // todo use MPI_Bcast

      for (dest = 1; dest <= numworkers; dest++)
      {
         rows = (dest <= extra) ? averow + 1 : averow;
         printf("Sending %d rows to task %d offset=%d\n", rows, dest, offset);
         MPI_Send(&offset, 1, MPI_INT, dest, mtype, MPI_COMM_WORLD);
         MPI_Send(&rows, 1, MPI_INT, dest, mtype, MPI_COMM_WORLD);
         MPI_Send(&A[offset][0], rows * n, MPI_INT, dest, mtype, MPI_COMM_WORLD);
         MPI_Send(&B[0][0], n * n, MPI_INT, dest, mtype, MPI_COMM_WORLD);
         offset += rows;
      }

      // test 31 times, ignoring first
      for (int i = 0; i <= 30; i++)
      {
         // TODO have master do stuff too ??
         // TODO see difference of times if masster helps or not
         start_time = MPI_Wtime();

         // signal workers to start
         for (dest = 1; dest <= numworkers; dest++)
         {
            MPI_Send(NULL, 0, MPI_INT, dest, START_MULTIPLY, MPI_COMM_WORLD);
         }

         // receive results from workers. source = worker
         mtype = FROM_WORKER;
         for (source = 1; source <= numworkers; source++)
         {
            MPI_Recv(&offset, 1, MPI_INT, source, mtype, MPI_COMM_WORLD, &status);
            MPI_Recv(&rows, 1, MPI_INT, source, mtype, MPI_COMM_WORLD, &status);
            MPI_Recv(&C[offset][0], rows * n, MPI_INT, source, mtype, MPI_COMM_WORLD, &status);
         }

         end_time = MPI_Wtime();
         multiplication_time = end_time - start_time;
         if (i > 0)
            results[i - 1] = multiplication_time;
      }

      mean = calculate_mean(results, result_size);

      FILE *result_log = fopen(result_log_name, "a");
      start_time = MPI_Wtime();
      print_matrix(result_log, C, n);
      end_time = MPI_Wtime();
      write_time = end_time - start_time;
      fclose(result_log);

      FILE *time_log = fopen(time_log_name, "a");
      fprintf(time_log, "Read time: %.8f seconds\nMultiplication time (avg): %.8f seconds\nWrite time: %.8f seconds", read_time, mean, write_time);
      fclose(time_log);

      // signal workers to stop
      for (dest = 1; dest <= numworkers; dest++)
      {
         MPI_Send(NULL, 0, MPI_INT, dest, STOP_WORKERS, MPI_COMM_WORLD);
      }
   }

   /**************************** Worker Tasks ************************************/
   if (taskid > MASTER)
   {
      // receive matrix data from master
      mtype = FROM_MASTER;
      MPI_Recv(&offset, 1, MPI_INT, MASTER, mtype, MPI_COMM_WORLD, &status);
      MPI_Recv(&rows, 1, MPI_INT, MASTER, mtype, MPI_COMM_WORLD, &status);
      MPI_Recv(&A[0][0], rows * n, MPI_INT, MASTER, mtype, MPI_COMM_WORLD, &status);
      MPI_Recv(&B[0][0], n * n, MPI_INT, MASTER, mtype, MPI_COMM_WORLD, &status);

      while (1)
      {
         // get signal from master to either start or stop multiplication
         MPI_Recv(NULL, 0, MPI_INT, MASTER, MPI_ANY_TAG, MPI_COMM_WORLD, &status);

         if (status.MPI_TAG == STOP_WORKERS)
            break;
         else if (status.MPI_TAG == START_MULTIPLY)
         {
            multiply_matrices(A, B, C, rows, n);

            // send results to master
            MPI_Send(&offset, 1, MPI_INT, MASTER, FROM_WORKER, MPI_COMM_WORLD);
            MPI_Send(&rows, 1, MPI_INT, MASTER, FROM_WORKER, MPI_COMM_WORLD);
            MPI_Send(&C[0][0], rows * n, MPI_INT, MASTER, FROM_WORKER, MPI_COMM_WORLD);
         }
      }
   }

   MPI_Finalize();
   return 0;
}
