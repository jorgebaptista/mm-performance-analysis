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

MATRIX_TYPE A[SIZE][SIZE];
MATRIX_TYPE B[SIZE][SIZE];
MATRIX_TYPE C[SIZE][SIZE];

double AVG_WORKER_TIMES[WORKERS];

void read_matrix(FILE *file, MATRIX_TYPE arr[SIZE][SIZE], int n, size_t start_element, double *time)
{
   double start_time = MPI_Wtime();

   size_t offset = start_element * sizeof(MATRIX_TYPE);
   fseek(file, offset, SEEK_SET);
   fread(arr[0], sizeof(MATRIX_TYPE), n * n, file);

   *time = MPI_Wtime() - start_time;
}

void print_matrix(FILE *file, MATRIX_TYPE C[SIZE][SIZE], int n, double *time)
{
   double start_time = MPI_Wtime();

   const char *format = (sizeof(MATRIX_TYPE) == sizeof(int)) ? "%d " : "%.2f ";

   for (int i = 0; i < n; i++)
   {
      for (int j = 0; j < n; j++)
      {
         fprintf(file, format, C[i][j]);
      }
      fprintf(file, "\n");
   }

   *time = MPI_Wtime() - start_time;
}

int main(int argc, char *argv[])
{
   int numtasks, taskid, dest, mtype, averow, extra, offset, rows;
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
      int numworkers = numtasks - 1;
      double read_time = 0.0, write_time = 0.0, avg_multi_times = 0.0;

      const char *matrix_file_name = argv[1];
      const char *time_log_name = argv[2];
      const char *result_log_name = argv[3];

      FILE *matrix_file = fopen(matrix_file_name, "rb");
      read_matrix(matrix_file, A, SIZE, 0, &read_time);
      read_matrix(matrix_file, B, SIZE, MAX_SIZE * MAX_SIZE, &read_time);
      fclose(matrix_file);

      // send matrix data to workers
      averow = SIZE / numworkers;
      extra = SIZE % numworkers;
      offset = 0;
      mtype = FROM_MASTER;

      for (int dest = 1; dest <= numworkers; dest++)
      {
         rows = (dest <= extra) ? averow + 1 : averow;
         MPI_Send(&offset, 1, MPI_INT, dest, mtype, MPI_COMM_WORLD);
         MPI_Send(&rows, 1, MPI_INT, dest, mtype, MPI_COMM_WORLD);
         MPI_Send(&A[offset][0], rows * SIZE, mpi_type, dest, mtype, MPI_COMM_WORLD);
         MPI_Send(&B[0][0], SIZE * SIZE, mpi_type, dest, mtype, MPI_COMM_WORLD);
         offset += rows;
      }

      for (int i = 0; i <= NRUNS; i++)
      {
         double start_time = MPI_Wtime();

         // TODO have master do stuff too ??
         // TODO see difference of times if masster helps or not

         for (int dest = 1; dest <= numworkers; dest++)
         {
            MPI_Send(&i, 1, MPI_INT, dest, START_MULTIPLY, MPI_COMM_WORLD); // Send current nrun
         }

         // receive results from workers. source = worker
         mtype = FROM_WORKER;
         for (int source = 1; source <= numworkers; source++)
         {
            MPI_Recv(&offset, 1, MPI_INT, source, mtype, MPI_COMM_WORLD, &status);
            MPI_Recv(&rows, 1, MPI_INT, source, mtype, MPI_COMM_WORLD, &status);
            MPI_Recv(&C[offset][0], rows * SIZE, mpi_type, source, mtype, MPI_COMM_WORLD, &status);
         }

         avg_multi_times += MPI_Wtime() - start_time;
      }

      for (int dest = 1; dest <= numworkers; dest++)
         MPI_Send(NULL, 0, MPI_INT, dest, STOP_WORKERS, MPI_COMM_WORLD); // stop workers

      FILE *result_log = fopen(result_log_name, "a");
      print_matrix(result_log, C, SIZE, &write_time);
      fclose(result_log);

      for (int i = 0; i < WORKERS; i++)
         AVG_WORKER_TIMES[i] /= NRUNS;

      avg_multi_times /= NRUNS;

      FILE *time_log = fopen(time_log_name, "a");
      fprintf(time_log, "Read time: %.8f seconds\nWrite time: %.8f seconds\nMultiplication time (avg): %.8f seconds\n", read_time, write_time, avg_multi_times);
      for (int i = 0; i < WORKERS; i++)
         fprintf(time_log, "Worker %d time (avg): %.8f seconds\n", i, AVG_WORKER_TIMES[i]);
      fclose(time_log);
   }

   /**************************** Worker Tasks ************************************/
   if (taskid > MASTER)
   {
      // receive matrix data from master
      mtype = FROM_MASTER;
      MPI_Recv(&offset, 1, MPI_INT, MASTER, mtype, MPI_COMM_WORLD, &status);
      MPI_Recv(&rows, 1, MPI_INT, MASTER, mtype, MPI_COMM_WORLD, &status);
      MPI_Recv(&A[0][0], rows * SIZE, mpi_type, MASTER, mtype, MPI_COMM_WORLD, &status);
      MPI_Recv(&B[0][0], SIZE * SIZE, mpi_type, MASTER, mtype, MPI_COMM_WORLD, &status);

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

            for (int i = 0; i < rows; i++)
            {
               for (int j = 0; j < SIZE; j++)
               {
                  MATRIX_TYPE sum = 0;
                  for (int k = 0; k < SIZE; k++)
                  {
                     sum += A[i][k] * B[k][j];
                  }
                  C[i][j] = sum;
               }
            }

            if (nrun > 0)
               AVG_WORKER_TIMES[taskid - 1] += MPI_Wtime() - start_time;

            // send results to master
            MPI_Send(&offset, 1, MPI_INT, MASTER, FROM_WORKER, MPI_COMM_WORLD);
            MPI_Send(&rows, 1, MPI_INT, MASTER, FROM_WORKER, MPI_COMM_WORLD);
            MPI_Send(&C[0][0], rows * SIZE, mpi_type, MASTER, FROM_WORKER, MPI_COMM_WORLD);
         }
      }
   }

   MPI_Finalize();
   return 0;
}
