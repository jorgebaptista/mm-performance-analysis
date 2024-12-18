#include <iostream>

int _ConvertSMVer2Cores(int major, int minor) {
    struct SMtoCores {
        int SM;
        int Cores;
    };

    // Table of SM versions
    static const SMtoCores SM_Cores_Table[] = {
        {0x30, 192},  // Kepler (3.x): 192 cores/SM
        {0x32, 192},  // Kepler (3.2): 192 cores/SM
        {0x35, 192},  // Kepler (3.5): 192 cores/SM
        {0x50, 128},  // Maxwell (5.0): 128 cores/SM
        {0x52, 128},  // Maxwell (5.2): 128 cores/SM
        {0x60, 64},   // Pascal (6.0): 64 cores/SM
        {0x61, 128},  // Pascal (6.1): 128 cores/SM
        {0x70, 64},   // Volta (7.0): 64 cores/SM
        {0x75, 64},   // Turing (7.5): 64 cores/SM
        {0x80, 64},   // Ampere (8.0): 64 cores/SM
        {0x86, 128},  // Ampere (8.6): 128 cores/SM
        {-1, -1}      // End marker
    };

    int sm_version = (major << 4) + minor;
    for (int i = 0; SM_Cores_Table[i].SM != -1; i++) {
        if (SM_Cores_Table[i].SM == sm_version) {
            return SM_Cores_Table[i].Cores;
        }
    }

    std::cerr << "Unknown SM version: " << major << "." << minor << "\n";
    return 0;
}

int main() {
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);

    for (int device = 0; device < deviceCount; device++) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, device);

        std::cout << "Device " << device << ": " << prop.name << "\n";
        std::cout << "  Compute capability: " << prop.major << "." << prop.minor << "\n";
        std::cout << "  Total Global Memory: " << prop.totalGlobalMem / (1024 * 1024) << " MB\n";
        std::cout << "  Multiprocessors: " << prop.multiProcessorCount << "\n";
        std::cout << "  CUDA Cores/MP: " << _ConvertSMVer2Cores(prop.major, prop.minor) << "\n";
        std::cout << "  Total CUDA Cores: " << prop.multiProcessorCount * _ConvertSMVer2Cores(prop.major, prop.minor) << "\n";
        std::cout << "  Max Threads/Block: " << prop.maxThreadsPerBlock << "\n";
        std::cout << "  Max Grid Size: (" << prop.maxGridSize[0] << ", " << prop.maxGridSize[1] << ", " << prop.maxGridSize[2] << ")\n";
        std::cout << "  Max Threads/Dimension: (" << prop.maxThreadsDim[0] << ", " << prop.maxThreadsDim[1] << ", " << prop.maxThreadsDim[2] << ")\n";
    }

    return 0;
}