#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifndef SIZE
#define SIZE 1024
#endif
#ifndef MATRIX_TYPE
#define MATRIX_TYPE int
#endif

MATRIX_TYPE **create_matrix(int n)
{
    MATRIX_TYPE **matrix = (MATRIX_TYPE **)malloc(n * sizeof(MATRIX_TYPE *));
    for (int i = 0; i < n; i++)
    {
        matrix[i] = (MATRIX_TYPE *)malloc(n * sizeof(MATRIX_TYPE));
    }
    return matrix;
}

// helper func to generate random values
MATRIX_TYPE generate_random_value()
{
    if (sizeof(MATRIX_TYPE) == sizeof(int))
    {
        return (MATRIX_TYPE)(rand() % 1000); // For integers
    }
    else if (sizeof(MATRIX_TYPE) == sizeof(float) || sizeof(MATRIX_TYPE) == sizeof(double))
    {
        return (MATRIX_TYPE)(rand() / (double)RAND_MAX * 1000.0); // For floats/doubles
    }
    return (MATRIX_TYPE)0; // Default case
}

// zeros and ones
void init_ones_matrix(MATRIX_TYPE **matrix, int n)
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
void init_diag_matrix(MATRIX_TYPE **matrix, int n)
{
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n; j++)
        {
            if (i == j)
                matrix[i][j] = 0;
            else
                matrix[i][j] = generate_random_value();
        }
    }
}

// all random
void init_matrix(MATRIX_TYPE **matrix, int n)
{
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            matrix[i][j] = generate_random_value();
}

void free_matrix(MATRIX_TYPE **matrix, int n)
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

    FILE *random_matrix_file = fopen(rand_matrix_file_name, "wb");
    MATRIX_TYPE **A = create_matrix(n);
    MATRIX_TYPE **B = create_matrix(n);
    init_matrix(A, n);
    init_matrix(B, n);
    fwrite(A[0], sizeof(MATRIX_TYPE), n * n, random_matrix_file);
    fwrite(B[0], sizeof(MATRIX_TYPE), n * n, random_matrix_file);
    fclose(random_matrix_file);

    FILE *diag_matrix_file = fopen(diag_matrix_file_name, "wb");
    A = create_matrix(n);
    B = create_matrix(n);
    init_diag_matrix(A, n);
    init_diag_matrix(B, n);
    fwrite(A[0], sizeof(MATRIX_TYPE), n * n, diag_matrix_file);
    fwrite(B[0], sizeof(MATRIX_TYPE), n * n, diag_matrix_file);
    fclose(diag_matrix_file);

    free_matrix(A, n);
    free_matrix(B, n);

    return 0;
}
