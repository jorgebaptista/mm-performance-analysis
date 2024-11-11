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

void print_matrix(int **matrix, int n, FILE *file)
{
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n; j++)
        {
            fprintf(file, "%d ", matrix[i][j]);
        }
        fprintf(file, "\n");
    }
}

int main(int argc, char const *argv[])
{
    srand(time(0));
    int n = SIZE;

    const char *matrix_file_name = argv[1];

    FILE *matrix_file = fopen(matrix_file_name, "w");
    int **A = create_matrix(n);
    int **B = create_matrix(n);
    init_matrix(A, n);
    init_matrix(B, n);
    print_matrix(A, n, matrix_file);
    print_matrix(B, n, matrix_file);
    fclose(matrix_file);

    free_matrix(A, n);
    free_matrix(B, n);

    return 0;
}
