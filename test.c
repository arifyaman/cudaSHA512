#include "sha512.c"
#include <sys/time.h>

long long timeInMilliseconds(void)
{
    struct timeval tv;

    gettimeofday(&tv, NULL);
    return (((long long)tv.tv_sec) * 1000) + (tv.tv_usec / 1000);
}

int main()
{
    unsigned char random[65] = {"d9b42e78fe3562f1e052fbdc7735abe085a74e5a910dd5c470ee00d03d1ddcee"};
    unsigned char hashed[64];

    SHA512_CTX ctx;

    long long start = timeInMilliseconds();

    for (int i = 0; i < 1000000; i++)
    {
        SHA512_Init(&ctx);
        SHA512_Update(&ctx, random, 64);
        SHA512_Final(hashed, &ctx);
    }

    long long end = timeInMilliseconds();

    printf("Bytes: ");
    for (int i = 0; i < 64; i++)
    {
        printf("%02x", hashed[i]);
    }

    printf("\n");
    printf("%lld", end - start);
}