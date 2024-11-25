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

int main(int argc, char *argv[])
{
   int numtasks, taskid, offset, rows;
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
      if (taskid == MASTER)
         fprintf(stderr, "Unsupported MATRIX_TYPE\n");
      MPI_Abort(MPI_COMM_WORLD, 1);
   }

   MPI_Init(&argc, &argv);
   MPI_Comm_rank(MPI_COMM_WORLD, &taskid);
   MPI_Comm_size(MPI_COMM_WORLD, &numtasks);

   if (numtasks != WORKERS)
   {
      if (taskid == MASTER)
         fprintf(stderr, "Number of workers must be %d\n", numtasks);
      MPI_Abort(MPI_COMM_WORLD, 1);
   }
   if (numtasks < 2)
   {
      if (taskid == MASTER)
         printf("Need at least two MPI tasks. Quitting...\n");
      MPI_Abort(MPI_COMM_WORLD, 0);
      exit(1);
   }

   const char *matrix_file_name = argv[1];
   const char *time_log_name = argv[2];
   const char *result_log_name = argv[3];

   double read_time = 0.0, write_time = 0.0, avg_multi_time = 0.0;

   int active_tasks = numtasks;
   if (SIZE < numtasks)
   {
      active_tasks = SIZE;
   }

   int averow = SIZE / active_tasks;
   int extra = SIZE % active_tasks;

   if (taskid < active_tasks)
   {
      if (taskid < extra)
      {
         rows = averow + 1;
         offset = taskid * rows;
      }
      else
      {
         rows = averow;
         offset = taskid * rows + extra;
      }
   }
   else
   {
      rows = 0; // No work for this worker
      offset = 0;
   }

   if (rows > 0)
   {
      A = (MATRIX_TYPE *)malloc(rows * SIZE * sizeof(MATRIX_TYPE));
      B = (MATRIX_TYPE *)malloc(SIZE * SIZE * sizeof(MATRIX_TYPE));
      C = (MATRIX_TYPE *)malloc(rows * SIZE * sizeof(MATRIX_TYPE));
   }

   MPI_File matrix_file;
   MPI_File_open(MPI_COMM_WORLD, matrix_file_name, MPI_MODE_RDONLY, MPI_INFO_NULL, &matrix_file);

   read_time = MPI_Wtime();
   if (rows > 0)
   {
      MPI_Offset a_offset = sizeof(MATRIX_TYPE) * offset * SIZE;
      MPI_File_read_at_all(matrix_file, a_offset, A, rows * SIZE, mpi_type, MPI_STATUS_IGNORE);
      MPI_Offset b_offset = sizeof(MATRIX_TYPE) * SIZE * SIZE;
      MPI_File_read_at_all(matrix_file, b_offset, B, SIZE * SIZE, mpi_type, MPI_STATUS_IGNORE);
      read_time = MPI_Wtime() - read_time;
   }
   else
   {
      MPI_File_read_at_all(matrix_file, 0, A, 0, mpi_type, MPI_STATUS_IGNORE);
      MPI_File_read_at_all(matrix_file, 0, B, 0, mpi_type, MPI_STATUS_IGNORE);
   }

   MPI_File_close(&matrix_file);

   if (rows > 0)
   {
      for (int run = 0; run <= NRUNS; run++)
      {
         double start_time = MPI_Wtime();

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

         if (run > 0)
            avg_multi_time += MPI_Wtime() - start_time;
      }
   }

   MPI_File result_file;
   MPI_File_open(MPI_COMM_WORLD, result_log_name, MPI_MODE_WRONLY | MPI_MODE_CREATE, MPI_INFO_NULL, &result_file);

   if (rows > 0)
   {
      write_time = MPI_Wtime();
      MPI_Offset c_offset = sizeof(MATRIX_TYPE) * offset * SIZE;
      MPI_File_write_at_all(result_file, c_offset, C, rows * SIZE, mpi_type, MPI_STATUS_IGNORE);
      write_time = MPI_Wtime() - write_time;
   }
   else
      MPI_File_write_at_all(result_file, 0, C, 0, mpi_type, MPI_STATUS_IGNORE);

   MPI_File_close(&result_file);

   avg_multi_time /= NRUNS;

   if (rows > 0)
   {
      free(A);
      free(B);
      free(C);
   }

   double total_avg_time, avg_read_time, avg_write_time, max_read_time, max_write_time;
   double avg_multi_times[active_tasks];
   MPI_Reduce(&avg_multi_time, &total_avg_time, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
   MPI_Gather(&avg_multi_time, 1, MPI_DOUBLE, avg_multi_times, 1, MPI_DOUBLE, MASTER, MPI_COMM_WORLD);
   MPI_Reduce(&read_time, &avg_read_time, 1, MPI_DOUBLE, MPI_SUM, MASTER, MPI_COMM_WORLD);
   MPI_Reduce(&write_time, &avg_write_time, 1, MPI_DOUBLE, MPI_SUM, MASTER, MPI_COMM_WORLD);
   MPI_Reduce(&read_time, &max_read_time, 1, MPI_DOUBLE, MPI_MAX, MASTER, MPI_COMM_WORLD);
   MPI_Reduce(&write_time, &max_write_time, 1, MPI_DOUBLE, MPI_MAX, MASTER, MPI_COMM_WORLD);

   if (taskid == MASTER)
   {
      total_avg_time /= active_tasks;
      avg_read_time /= active_tasks;
      avg_write_time /= active_tasks;

      int max_worker = 0;
      for (int i = 0; i < active_tasks; i++)
         if (avg_multi_times[i] > avg_multi_times[max_worker])
            max_worker = i;

      FILE *time_log = fopen(time_log_name, "a");
      fprintf(time_log, "Read time (avg): %.8f seconds\nRead time (max): %.8f seconds\nWrite time (avg): %.8f seconds\nWrite time (max): %.8f seconds\nMultiplication time (avg): %.8f seconds\n", avg_read_time, max_read_time, avg_write_time, max_write_time, total_avg_time);
      for (int i = 0; i < WORKERS; i++)
      {
         if (i == max_worker)
            fprintf(time_log, "Worker %d time (avg): %.8f seconds (max)\n", i, avg_multi_times[i]);
         else
            fprintf(time_log, "Worker %d time (avg): %.8f seconds\n", i, avg_multi_times[i]);
      }

      fclose(time_log);
   }

   MPI_Finalize();
   return 0;
}
