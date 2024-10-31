# mm-performance-analysis
Performance analysis of matrix multiplication code using various techniques such as:

- [**Serial**](serial) - Execution on a single CPU core, processing each operation sequentially
- [**MPI**](mpi) - Distributes matrix rows across multiple CPU cores on separate nodes for parallel computation
- [**OpenMP**](openmp) - Uses threads within a shared memory system to parallelize operations across multiple CPU cores
- **Hybrid** - Combines MPI and OpenMP to maximize resource utilization
- ...
