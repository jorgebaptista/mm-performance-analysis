#include <stdio.h>
#include <stdlib.h>
#include "mpi.h"

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
#ifndef WORKERS
#define WORKERS 4
#endif

#define MASTER 0
#define FROM_MASTER 1
#define FROM_WORKER 2
#define START_MULTIPLY 3
#define STOP_WORKERS 4

MATRIX_TYPE *A;
MATRIX_TYPE *B;
MATRIX_TYPE *C;

void read_matrix(FILE *file, MATRIX_TYPE *arr, int n, size_t start_element, double *time)
{
   double start_time = MPI_Wtime();

   size_t offset = start_element * sizeof(MATRIX_TYPE);
   fseek(file, offset, SEEK_SET);
   fread(arr, sizeof(MATRIX_TYPE), n * n, file);

   *time = MPI_Wtime() - start_time;
}

void print_matrix(FILE *file, MATRIX_TYPE *C, int n, double *time)
{
   double start_time = MPI_Wtime();

   const char *format = (sizeof(MATRIX_TYPE) == sizeof(int)) ? "%d " : "%.2f ";

   for (int i = 0; i < n; i++)
   {
      for (int j = 0; j < n; j++)
      {
         fprintf(file, format, C[i * n + j]);
      }
      fprintf(file, "\n");
   }

   *time = MPI_Wtime() - start_time;
}

int main(int argc, char *argv[])
{
   int numtasks, taskid, offset, rows;
   MPI_Status status;
   MPI_Datatype mpi_type;
   if (sizeof(MATRIX_TYPE) == sizeof(int))
   {
      mpi_type = MPI_INT;
   }
   else if (sizeof(MATRIX_TYPE) == sizeof(double))
   {
      mpi_type = MPI_DOUBLE;
   }
   else if (sizeof(MATRIX_TYPE) == sizeof(float))
   {
      mpi_type = MPI_FLOAT;
   }
   else
   {
      fprintf(stderr, "Unsupported MATRIX_TYPE\n");
      MPI_Abort(MPI_COMM_WORLD, 1);
   }

   MPI_Init(&argc, &argv);
   MPI_Comm_rank(MPI_COMM_WORLD, &taskid);
   MPI_Comm_size(MPI_COMM_WORLD, &numtasks);

   if (numtasks != WORKERS)
   {
      fprintf(stderr, "Number of workers must be %d\n", numtasks);
      MPI_Abort(MPI_COMM_WORLD, 1);
   }
   if (numtasks < 2)
   {
      printf("Need at least two MPI tasks. Quitting...\n");
      MPI_Abort(MPI_COMM_WORLD, 0);
      exit(1);
   }

   /**************************** Master Task ************************************/
   if (taskid == MASTER)
   {
      double read_time = 0.0, write_time = 0.0, avg_multi_times = 0.0,
             avg_worker_times[WORKERS] = {0.0}, worker_times[NRUNS][WORKERS];

      int master_offset = 0, master_rows = 0;

      A = (MATRIX_TYPE *)malloc(SIZE * SIZE * sizeof(MATRIX_TYPE));
      B = (MATRIX_TYPE *)malloc(SIZE * SIZE * sizeof(MATRIX_TYPE));
      C = (MATRIX_TYPE *)malloc(SIZE * SIZE * sizeof(MATRIX_TYPE));

      const char *matrix_file_name = argv[1];
      const char *time_log_name = argv[2];
      const char *result_log_name = argv[3];

      FILE *matrix_file = fopen(matrix_file_name, "rb");
      read_matrix(matrix_file, A, SIZE, 0, &read_time);
      read_matrix(matrix_file, B, SIZE, MAX_SIZE * MAX_SIZE, &read_time);
      fclose(matrix_file);

      // send matrix data to workers
      int averow = SIZE / numtasks;
      int extra = SIZE % numtasks;
      offset = 0;

      for (int dest = 0; dest < numtasks; dest++)
      {
         rows = averow;
         if (dest != MASTER)
         {
            if (extra > 0)
            {
               rows++;
               extra--;
            }

            MPI_Send(&offset, 1, MPI_INT, dest, FROM_MASTER, MPI_COMM_WORLD);
            MPI_Send(&rows, 1, MPI_INT, dest, FROM_MASTER, MPI_COMM_WORLD);
            MPI_Send(&A[offset * SIZE], rows * SIZE, mpi_type, dest, FROM_MASTER, MPI_COMM_WORLD);
            MPI_Send(B, SIZE * SIZE, mpi_type, dest, FROM_MASTER, MPI_COMM_WORLD);
         }
         else
         {
            master_offset = offset;
            master_rows = rows;
         }
         offset += rows;
      }

      for (int i = 0; i <= NRUNS; i++)
      {
         double start_time = MPI_Wtime();

         for (int dest = 1; dest < numtasks; dest++)
            MPI_Send(&i, 1, MPI_INT, dest, START_MULTIPLY, MPI_COMM_WORLD); // Send current nrun

         double master_time = MPI_Wtime();
         for (int i = master_offset; i < master_offset + master_rows; i++)
         {
            for (int j = 0; j < SIZE; j++)
            {
               MATRIX_TYPE sum = 0;
               for (int k = 0; k < SIZE; k++)
               {
                  sum += A[i * SIZE + k] * B[k * SIZE + j];
               }
               C[i * SIZE + j] = sum;
            }
         }

         if (i > 0)
            worker_times[i - 1][MASTER] += MPI_Wtime() - master_time;

         // receive results from workers. source = worker
         for (int source = 1; source < numtasks; source++)
         {
            MPI_Recv(&offset, 1, MPI_INT, source, FROM_WORKER, MPI_COMM_WORLD, &status);
            MPI_Recv(&rows, 1, MPI_INT, source, FROM_WORKER, MPI_COMM_WORLD, &status);
            MPI_Recv(&C[offset * SIZE], rows * SIZE, mpi_type, source, FROM_WORKER, MPI_COMM_WORLD, &status);
            MPI_Recv(&worker_times[i - 1][source], 1, MPI_DOUBLE, source, FROM_WORKER, MPI_COMM_WORLD, &status);
         }

         if (i > 0)
            avg_multi_times += MPI_Wtime() - start_time;
      }

      for (int dest = 1; dest < numtasks; dest++)
         MPI_Send(NULL, 0, MPI_INT, dest, STOP_WORKERS, MPI_COMM_WORLD); // stop workers

      FILE *result_log = fopen(result_log_name, "a");
      print_matrix(result_log, C, SIZE, &write_time);
      fclose(result_log);

      for (int i = 0; i < NRUNS; i++)
         for (int j = 0; j < WORKERS; j++)
            avg_worker_times[j] += worker_times[i][j];

      for (int i = 0; i < WORKERS; i++)
         avg_worker_times[i] /= NRUNS;

      avg_multi_times /= NRUNS;

      FILE *time_log = fopen(time_log_name, "a");
      fprintf(time_log, "Read time: %.8f seconds\nWrite time: %.8f seconds\nMultiplication time (avg): %.8f seconds\n", read_time, write_time, avg_multi_times);
      for (int i = 0; i < WORKERS; i++)
      {
         if (i == 0)
            fprintf(time_log, "Master time (avg): %.8f seconds\n", avg_worker_times[i]);
         else
            fprintf(time_log, "Worker %d time (avg): %.8f seconds\n", i, avg_worker_times[i]);
      }
      fclose(time_log);
   }

   /**************************** Worker Tasks ************************************/
   if (taskid > MASTER)
   {
      MPI_Recv(&offset, 1, MPI_INT, MASTER, FROM_MASTER, MPI_COMM_WORLD, &status);
      MPI_Recv(&rows, 1, MPI_INT, MASTER, FROM_MASTER, MPI_COMM_WORLD, &status);

      A = (MATRIX_TYPE *)malloc(rows * SIZE * sizeof(MATRIX_TYPE));
      B = (MATRIX_TYPE *)malloc(SIZE * SIZE * sizeof(MATRIX_TYPE));
      C = (MATRIX_TYPE *)malloc(rows * SIZE * sizeof(MATRIX_TYPE));

      // receive matrix data from master
      MPI_Recv(A, rows * SIZE, mpi_type, MASTER, FROM_MASTER, MPI_COMM_WORLD, &status);
      MPI_Recv(B, SIZE * SIZE, mpi_type, MASTER, FROM_MASTER, MPI_COMM_WORLD, &status);

      int nrun;
      while (1)
      {
         // get signal from master to either start or stop multiplication
         MPI_Recv(&nrun, 1, MPI_INT, MASTER, MPI_ANY_TAG, MPI_COMM_WORLD, &status); // Get current nrun

         if (status.MPI_TAG == STOP_WORKERS)
            break;
         else if (status.MPI_TAG == START_MULTIPLY)
         {
            double start_time = MPI_Wtime();
            double worker_time;

            for (int i = 0; i < rows; i++)
            {
               for (int j = 0; j < SIZE; j++)
               {
                  MATRIX_TYPE sum = 0;
                  for (int k = 0; k < SIZE; k++)
                  {
                     sum += A[i * SIZE + k] * B[k * SIZE + j];
                  }
                  C[i * SIZE + j] = sum;
               }
            }

            if (nrun > 0)
               worker_time = MPI_Wtime() - start_time;

            // send results to master
            MPI_Send(&offset, 1, MPI_INT, MASTER, FROM_WORKER, MPI_COMM_WORLD);
            MPI_Send(&rows, 1, MPI_INT, MASTER, FROM_WORKER, MPI_COMM_WORLD);
            MPI_Send(C, rows * SIZE, mpi_type, MASTER, FROM_WORKER, MPI_COMM_WORLD);
            MPI_Send(&worker_time, 1, MPI_DOUBLE, MASTER, FROM_WORKER, MPI_COMM_WORLD);
         }
      }
   }

   free(A);
   free(B);
   free(C);

   MPI_Finalize();
   return 0;
}
