#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <cuda.h>
#include <sys/time.h>
#include <pthread.h>
#include <locale.h>
#include "sha512.cuh"

#define CHECK_TOP_N2 539858690
#define CHECK_LOW_N2 41848688

#define CHECK_TOP 25000000
#define CHECK_LOW 22222222

/* #define CHECK_TOP_N2 639858689
#define CHECK_LOW_N2 3398988

#define CHECK_TOP 50000000
#define CHECK_LOW 40000000 */


#define INPUT_SIZE 865
#define HASH_SIZE 64

#define THREADS 2000
#define BLOCKS 128

__constant__ unsigned char digits[11] = {"0123456789"};
__constant__ unsigned char input_p2[512] = {"],\"license\":{\"type\":\"gambling-virtual\",\"text\":\"Random values licensed for virtual item gambling only\",\"infoUrl\":null},\"licenseData\":null,\"userData\":\"Those numbers were generated for Crash game on INSANE.gg. The firstNumber in sequence determines the chance of x1 (instant crash). If the number is less than 40000000 (4.0% chance), then x1 will be rolled, otherwise the secondNumber in sequence is used to generate the multiplier using the formula: 1000000000 : secondNumber\",\"ticketData\":null,\"completionTime\":\""};
// 2023-04-05 18:46:58Z","serialNumber":2365441}
// 541210fe506cb91708ebd4f6c8f19525b4286ee32b338d3deb8197e71542719ce2d6a80c359abf74db192b992d4a8df10b3abc85b416a60630b5c75439ec21d4,2023-04-05 18:46:58Z,2365441
unsigned char input_p1[243] = {"{\"method\":\"generateSignedIntegers\",\"hashedApiKey\":\"DilGPW5gs5jzIsxz/8kSjH+WTLsNEQtmtrTFyq3tvgpolF41vhTwtE6iG8FT+WzdhzQZd4GBNp5q6VixloAUlA==\",\"n\":2,\"min\":0,\"max\":1000000000,\"replacement\":true,\"base\":10,\"pregeneratedRandomization\":null,\"data\":["};
unsigned char input_data[20] = {"428529917,883048505"};

__device__ void updatWithNumber(unsigned int n, unsigned char *digits, SHA512_CTX *ctx)
{

    unsigned int divisor = 1;
    while (n / divisor >= 10)
    {
        divisor *= 10;
    }
    while (divisor > 0)
    {
        SHA512_Update(ctx, &digits[(n / divisor) % 10], 1);

        divisor /= 10;
    }
}

__device__ void updateWithTimeAndSerial(unsigned char *completionTime, unsigned char *serialNumber, SHA512_CTX *ctx)
{
    SHA512_Update(ctx, completionTime, 20);
    SHA512_Update(ctx, "\",\"serialNumber\":", 17);
    SHA512_Update(ctx, serialNumber, 7);
    SHA512_Update(ctx, "}", 1);
}

__device__ void updateWithAsumedData(unsigned int seed, SHA512_CTX *ctx, unsigned int *numbers)
{
    numbers[0] = CHECK_LOW_N2 + (int)((seed + 1) / (CHECK_TOP - CHECK_LOW));
    numbers[1] = CHECK_TOP - ((seed + 1) % (CHECK_TOP - CHECK_LOW));

    updatWithNumber(numbers[0], digits, ctx);
    SHA512_Update(ctx, ",", 1);
    updatWithNumber(numbers[1], digits, ctx);
}

__global__ void sha512_kernel(SHA512_CTX *ctx, unsigned int seed, unsigned char *output, unsigned char *expectedHash, unsigned int *solution, int *blockSolution, unsigned char *completionTime, unsigned char *serialNumber)
{

    if (*blockSolution == 1)
        return;

    int i = blockIdx.x * blockDim.x * seed + threadIdx.x;

    SHA512_CTX copiedContext;
    memcpy(&copiedContext, ctx, sizeof(SHA512_CTX));

    unsigned int numbers[2];
    unsigned char foundHash[64];

    updateWithAsumedData(i, &copiedContext, numbers);

    SHA512_Update(&copiedContext, input_p2, 511);
    updateWithTimeAndSerial(completionTime, serialNumber, &copiedContext);

    SHA512_Final(foundHash, &copiedContext);

    for (int j = 0; j < 64; j++)
        if (expectedHash[j] != foundHash[j])
            return;

    *blockSolution = 1;
    memcpy(solution, numbers, sizeof(unsigned int) * 2);
}

__global__ void sha512_init_context_kernel(unsigned char *input, SHA512_CTX *ctx)
{

    SHA512_Init(ctx);
    SHA512_Update(ctx, input, 242);
}

long long timeInMilliseconds(void)
{
    struct timeval tv;

    gettimeofday(&tv, NULL);
    return (((long long)tv.tv_sec) * 1000) + (tv.tv_usec / 1000);
}

int main(int argc, char *argv[])
{
    //printf("%s %d\n", argv[1], argc);
    // Initialize context

    SHA512_CTX *sha_512_ctx = (SHA512_CTX *)malloc(sizeof(SHA512_CTX));
    SHA512_CTX *d_sha_512_ctx;
    cudaMalloc(&d_sha_512_ctx, sizeof(SHA512_CTX));
    cudaMemcpy(d_sha_512_ctx, sha_512_ctx, sizeof(SHA512_CTX), cudaMemcpyHostToDevice);

    // Allocate memory on device for input and output
    unsigned char *d_input_p1;
    cudaMalloc((void **)&d_input_p1, sizeof(char) * 243);
    cudaMemcpy(d_input_p1, input_p1, sizeof(char) * 243, cudaMemcpyHostToDevice);

    unsigned int *blockSolution = (unsigned int *)malloc(sizeof(unsigned int) * 2);
    unsigned int *d_solution;
    cudaMalloc(&d_solution, sizeof(unsigned int) * 2);

    int *blockContainsSolution = (int *)malloc(sizeof(int));
    int *d_blockContainsSolution;
    cudaMalloc(&d_blockContainsSolution, sizeof(int));

    cudaMemcpyToSymbol(dev_K512, K512, sizeof(K512), 0, cudaMemcpyHostToDevice);

    sha512_init_context_kernel<<<1, 1>>>(d_input_p1, d_sha_512_ctx);

    // cudaDeviceSynchronize();

    unsigned char *d_output;
    cudaMalloc((void **)&d_output, sizeof(char) * HASH_SIZE);

    // Copy input data from host to device

    unsigned char inputFromCmd[500];

    scanf("%500[^\n]", inputFromCmd);

    unsigned char hashedBytes[64];
    unsigned char completionTime[21];
    unsigned char serialNumber[8];

    int i;
    // Convert the hex-encoded SHA512 hashed string to a byte array
    for (i = 0; i < 64; i++)
    {
        char hex[3];
        hex[0] = inputFromCmd[2 * i];
        hex[1] = inputFromCmd[2 * i + 1];
        hex[2] = '\0';
        hashedBytes[i] = (uint8_t)strtol(hex, NULL, 16);
    }
    memcpy(completionTime, &inputFromCmd[129], sizeof(char) * 20);
    completionTime[20] = '\0';
    memcpy(serialNumber, &inputFromCmd[150], sizeof(char) * 7);
    serialNumber[7] = '\0';

    //printf("%s\n%s\n", completionTime, serialNumber);

    unsigned char *d_expectedHash;
    cudaMalloc((void **)&d_expectedHash, sizeof(char) * 64);
    cudaMemcpy(d_expectedHash, hashedBytes, sizeof(char) * 64, cudaMemcpyHostToDevice);

    unsigned char *d_completionTime;
    cudaMalloc((void **)&d_completionTime, sizeof(char) * 21);
    cudaMemcpy(d_completionTime, completionTime, sizeof(char) * 21, cudaMemcpyHostToDevice);

    unsigned char *d_serialNumber;
    cudaMalloc((void **)&d_serialNumber, sizeof(char) * 8);
    cudaMemcpy(d_serialNumber, serialNumber, sizeof(char) * 8, cudaMemcpyHostToDevice);

    unsigned long hashCount = 0;
    long long start = timeInMilliseconds();

    unsigned int seed = 0;

    while (1)
    {
        hashCount += THREADS * BLOCKS;
        // Run SHA512 kernel
        sha512_kernel<<<THREADS, BLOCKS>>>(d_sha_512_ctx, seed, d_output, d_expectedHash, d_solution, d_blockContainsSolution, d_completionTime, d_serialNumber);

        cudaDeviceSynchronize();

        cudaMemcpy(blockContainsSolution, d_blockContainsSolution, sizeof(int), cudaMemcpyDeviceToHost);
        if (*blockContainsSolution == 1)
        {
            cudaMemcpy(blockSolution, d_solution, sizeof(unsigned int) * 2, cudaMemcpyDeviceToHost);
            printf("%u,%u", blockSolution[0], blockSolution[1]);
            break;
        }

        //long long elapsed = timeInMilliseconds() - start;
        //printf("Hashes (%'lu) Seconds (%'f) Hashes/sec (%'lu)\r", hashCount, ((float)elapsed) / 1000.0, (unsigned long)((double)hashCount / (double)elapsed) * 1000);
        seed++;
    }

    // Copy output data from device to host
    unsigned char output[HASH_SIZE];
    cudaMemcpy(output, d_output, HASH_SIZE, cudaMemcpyDeviceToHost);

    // Print output hash
    /* printf("Output hash: ");
    for (int i = 0; i < HASH_SIZE; i++)
    {
        printf("%02x", output[i]);
    }
    printf("\n"); */

    // Free memory on device
    cudaFree(d_sha_512_ctx);
    cudaFree(dev_K512);
    cudaFree(d_expectedHash);
    cudaFree(d_solution);
    cudaFree(d_blockContainsSolution);
    cudaFree(d_output);

    return 0;
}
