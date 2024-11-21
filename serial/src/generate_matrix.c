#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifndef SIZE
#define SIZE 1024
#endif

int **create_matrix(int n)
{
    int **matrix = (int **)malloc(n * sizeof(int *));
    for (int i = 0; i < n; i++)
    {
        matrix[i] = (int *)malloc(n * sizeof(int));
    }
    return matrix;
}

// zeros and ones
void init_ones_matrix(int **matrix, int n)
{
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n; j++)
        {
            if (i == j)
                matrix[i][j] = 0;
            else
                matrix[i][j] = 1;
        }
    }
}

// random w diagonal zeroes
void init_diag_matrix(int **matrix, int n)
{
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n; j++)
        {
            if (i == j)
                matrix[i][j] = 0;
            else
                matrix[i][j] = rand() % 1000;
        }
    }
}

// all random
void init_matrix(int **matrix, int n)
{
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            matrix[i][j] = rand() % 1000;
}

void free_matrix(int **matrix, int n)
{
    for (int i = 0; i < n; i++)
    {
        free(matrix[i]);
    }
    free(matrix);
}

int main(int argc, char const *argv[])
{
    srand(time(0));
    int n = SIZE;

    const char *rand_matrix_file_name = argv[1];
    const char *diag_matrix_file_name = argv[2];

    FILE *random_matrix_file = fopen(rand_matrix_file_name, "w");
    int **A = create_matrix(n);
    int **B = create_matrix(n);
    init_matrix(A, n);
    init_matrix(B, n);
    fwrite(A[0], sizeof(int), n * n, random_matrix_file);
    fwrite(B[0], sizeof(int), n * n, random_matrix_file);
    fclose(random_matrix_file);

    FILE *diag_matrix_file = fopen(diag_matrix_file_name, "w");
    A = create_matrix(n);
    B = create_matrix(n);
    init_diag_matrix(A, n);
    init_diag_matrix(B, n);
    fwrite(A[0], sizeof(int), n * n, diag_matrix_file);
    fwrite(B[0], sizeof(int), n * n, diag_matrix_file);
    fclose(diag_matrix_file);

    free_matrix(A, n);
    free_matrix(B, n);

    return 0;
}
