#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cuda.h>
#include <sys/time.h>
#include <pthread.h>
#include <locale.h>
#include "sha512.cuh"

#define INPUT_SIZE 2
#define HASH_SIZE 64

#define THREADS 1200
#define BLOCKS 256

__global__ void sha512_kernel(unsigned char *input, unsigned char *output)
{
    SHA512_CTX ctx;
    SHA512_Init(&ctx);
    SHA512_Update(&ctx, input, INPUT_SIZE);
    SHA512_Final(output, &ctx);
}

int main()
{
    // Initialize input data
    char input[] = {"ay"};

    // Allocate memory on device for input and output
    unsigned char *d_input, *d_output;
    cudaMalloc((void **)&d_input, INPUT_SIZE);
    cudaMalloc((void **)&d_output, HASH_SIZE);

    // Copy input data from host to device
    cudaMemcpy(d_input, input, sizeof(char) * INPUT_SIZE, cudaMemcpyHostToDevice);

    cudaMemcpyToSymbol(dev_K512, K512, sizeof(K512), 0, cudaMemcpyHostToDevice);
    // Run SHA512 kernel
    sha512_kernel<<<THREADS, BLOCKS>>>(d_input, d_output);

    // Copy output data from device to host
    unsigned char output[HASH_SIZE];
    cudaMemcpy(output, d_output, HASH_SIZE, cudaMemcpyDeviceToHost);

    // Print output hash
    printf("Output hash: ");
    for (int i = 0; i < HASH_SIZE; i++)
    {
        printf("%02x", output[i]);
    }
    printf("\n");

    // Free memory on device
    cudaFree(dev_K512);
    cudaFree(d_input);
    cudaFree(d_output);

    return 0;
}
