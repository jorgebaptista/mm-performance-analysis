#include <stdio.h>
#include <stdlib.h>
#include <time.h>

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
    int n = 1024;

    FILE *diag_matrix_file = fopen("../data/diag_matrix.txt", "w");
    fprintf(diag_matrix_file, "%d\n", n);
    int **A = create_matrix(n);
    int **B = create_matrix(n);
    init_diag_matrix(A, n);
    init_diag_matrix(B, n);
    print_matrix(A, n, diag_matrix_file);
    print_matrix(B, n, diag_matrix_file);
    fclose(diag_matrix_file);

    FILE *random_matrix_file = fopen("../data/random_matrix.txt", "w");
    fprintf(random_matrix_file, "%d\n", n);
    A = create_matrix(n);
    B = create_matrix(n);
    init_matrix(A, n);
    init_matrix(B, n);
    print_matrix(A, n, random_matrix_file);
    print_matrix(B, n, random_matrix_file);
    fclose(random_matrix_file);
    
    free_matrix(A, n);
    free_matrix(B, n);

    return 0;
}
