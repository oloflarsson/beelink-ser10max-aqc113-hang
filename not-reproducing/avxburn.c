// avxburn — a tiny, shareable CPU power-virus with a selectable instruction mix.
//   avxburn <mode> <threads> <seconds>     mode = avx512 | avx2 | scalar
// Each thread runs a dependent-free FMA chain on registers only (no memory
// traffic), which is the highest-power instruction mix a Zen 5 core can run.
// Build:  gcc -O2 -pthread -mavx512f -mavx2 -mfma -o avxburn avxburn.c
#include <immintrin.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static volatile int stop = 0;
static int mode = 0; // 0 scalar, 1 avx2, 2 avx512
static double sink[256];

__attribute__((target("avx512f"))) static void burn512(int id) {
    __m512d a[8]; __m512d m = _mm512_set1_pd(1.0000001), c = _mm512_set1_pd(1e-9);
    for (int i = 0; i < 8; i++) a[i] = _mm512_set1_pd(1.0 + i + id);
    while (!stop) for (int k = 0; k < 4096; k++) for (int i = 0; i < 8; i++) a[i] = _mm512_fmadd_pd(a[i], m, c);
    double t[8]; _mm512_storeu_pd(t, a[0]); sink[id % 256] = t[0];
}
__attribute__((target("avx2,fma"))) static void burn256(int id) {
    __m256d a[8]; __m256d m = _mm256_set1_pd(1.0000001), c = _mm256_set1_pd(1e-9);
    for (int i = 0; i < 8; i++) a[i] = _mm256_set1_pd(1.0 + i + id);
    while (!stop) for (int k = 0; k < 4096; k++) for (int i = 0; i < 8; i++) a[i] = _mm256_fmadd_pd(a[i], m, c);
    double t[4]; _mm256_storeu_pd(t, a[0]); sink[id % 256] = t[0];
}
static void burnscalar(int id) {
    double a[8]; for (int i = 0; i < 8; i++) a[i] = 1.0 + i + id;
    while (!stop) for (int k = 0; k < 4096; k++) for (int i = 0; i < 8; i++) a[i] = a[i] * 1.0000001 + 1e-9;
    sink[id % 256] = a[0];
}
static void *worker(void *p) {
    int id = (int)(long)p;
    if (mode == 2) burn512(id); else if (mode == 1) burn256(id); else burnscalar(id);
    return NULL;
}
int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s avx512|avx2|scalar <threads> <seconds>\n", argv[0]); return 2; }
    mode = !strcmp(argv[1], "avx512") ? 2 : !strcmp(argv[1], "avx2") ? 1 : 0;
    int n = atoi(argv[2]), secs = atoi(argv[3]);
    pthread_t th[512];
    for (long i = 0; i < n; i++) pthread_create(&th[i], NULL, worker, (void *)i);
    struct timespec ts = {1, 0};
    for (int s = 0; s < secs; s++) nanosleep(&ts, NULL);
    stop = 1;
    for (int i = 0; i < n; i++) pthread_join(th[i], NULL);
    printf("done mode=%s threads=%d secs=%d\n", argv[1], n, secs);
    return 0;
}
