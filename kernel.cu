#include <iostream>
#include <time.h>
#include <math.h>

//#include <cuda.h>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

using std::cout; using std::cin;

#define array_size 20

__device__ float sumtotal;

//void ImpError(cudaError_t err);

void ImpError(cudaError_t err)
{
	cout << cudaGetErrorString(err); // << " en " << __FILE__ << __LINE__;
	//exit(EXIT_FAILURE);
}


__global__
void vecAddKernel(float* A, float* B, float* C, int n)
{
	int i = blockDim.x * blockIdx.x + threadIdx.x;
	if (i < n)
		C[i] = A[i] + B[i];
}


void vecAdd(float* A, float* B, float* C, int n)
{
	int size = n * sizeof(float);
	float* d_A, * d_B, * d_C;

	cudaError_t err = cudaSuccess;

	err = cudaMalloc((void**)& d_A, size);

	if (err != cudaSuccess)
	{
		cout << "d_A";
		ImpError(err);
	}


	err = cudaMemcpy(d_A, A, size, cudaMemcpyHostToDevice);

	if (err != cudaSuccess)
		ImpError(err);

	err = cudaMalloc((void**)& d_B, size);

	if (err != cudaSuccess)
		ImpError(err);

	err = cudaMemcpy(d_B, B, size, cudaMemcpyHostToDevice);

	if (err != cudaSuccess)
		ImpError(err);

	err = cudaMalloc((void**)& d_C, size);

	if (err != cudaSuccess)
		ImpError(err);

	//<<#bloques,#threads por bloques>>
	vecAddKernel << <ceil(n / 512.0), 512 >> > (d_A, d_B, d_C, n);

	err = cudaMemcpy(C, d_C, size, cudaMemcpyDeviceToHost);

	if (err != cudaSuccess)
		ImpError(err);

	cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
}


// Implementacion simple fig 5.13
__global__ void SimpleReduce(float* vec_x, float* sum)
{
	unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;

	__shared__ float partialSum[array_size];
	partialSum[threadIdx.x]	= vec_x[i];

	unsigned int t = threadIdx.x;
	

	//if (t < array_size)
	//{
		for (unsigned int stride = 1; stride < blockDim.x; stride *= 2)
		{

			__syncthreads();
			if ( (t % (2 * stride) == 0) && (t+stride) < array_size  )
			{
				partialSum[t] += partialSum[t + stride];
			}
		}	
	//}

		__syncthreads();


	// write result for this block to global mem
	//if (tid == 0)
		//g_odata[blockIdx.x] = sdata[0];
	if (threadIdx.x == 0)
	{
		sum[0] = partialSum[0];
		sumtotal = partialSum[0];
	}
	
}


__global__ void Reduce(unsigned int* g_odata, unsigned int* g_idata, unsigned int len) {
	extern __shared__ unsigned int sdata[];

	unsigned int tid = threadIdx.x;
	unsigned int i = blockIdx.x * (blockDim.x * 2) + threadIdx.x;

	sdata[tid] = 0;

	if (i < len)
	{
		sdata[tid] = g_idata[i] + g_idata[i + blockDim.x];
	}

	__syncthreads();

	// do reduction in shared mem
	// this loop now starts with s = 512 / 2 = 256
	for (unsigned int s = blockDim.x / 2; s > 0; s >>= 1) {
		if (tid < s) {
			sdata[tid] += sdata[tid + s];
		}
		__syncthreads();
	}

	// write result for this block to global mem
	if (tid == 0)
		g_odata[blockIdx.x] = sdata[0];
}

__global__ void reduce4(unsigned int* g_odata, unsigned int* g_idata, unsigned int len) {
	extern __shared__ unsigned int* sdata;

	unsigned int tid = threadIdx.x;
	unsigned int i = blockIdx.x * (blockDim.x * 2) + threadIdx.x;

	sdata[tid] = 0;

	if (i < len)
	{
		sdata[tid] = g_idata[i] + g_idata[i + blockDim.x];
	}

	__syncthreads();

	for (unsigned int s = blockDim.x / 2; s > 32; s >>= 1) {
		if (tid < s) {
			sdata[tid] += sdata[tid + s];
		}
		__syncthreads();
	}

	if (tid < 32)
	{
		sdata[tid] += sdata[tid + 32];
		sdata[tid] += sdata[tid + 16];
		sdata[tid] += sdata[tid + 8];
		sdata[tid] += sdata[tid + 4];
		sdata[tid] += sdata[tid + 2];
		sdata[tid] += sdata[tid + 1];
	}

	if (tid == 0)
		g_odata[blockIdx.x] = sdata[0];
}

void vecSum(float* A, float* sum)
{
	int size = array_size * sizeof(float);
	float* d_A, *d_sum;


	cudaError_t err = cudaSuccess;

	err = cudaMalloc((void**)& d_A, size);
	err = cudaMalloc((void**)& d_sum, sizeof(float));

	if (err != cudaSuccess)
	{
		cout << "d_A";
		ImpError(err);
	}

	cudaMemcpy(d_A, A, size, cudaMemcpyHostToDevice);

	//<<#bloques,#threads por bloques>>
	SimpleReduce << <ceil(array_size / 512.0), 512 >> > (d_A, d_sum);

	//err = cudaMemcpy(sum, d_sum, sizeof(float), cudaMemcpyDeviceToHost);

	if (err != cudaSuccess)
	{
		cout << "aqui";
		ImpError(err);
	}
		

	cudaFree(d_A);
}


void Imprimir(float* A, int n)
{
	for (int i = 0; i < n; ++i)
		if (i < n) cout << A[i] << " ";
	cout << "\n";
}

void GenVector(float* A, int n)
{

	for (int i = 0; i < n; ++i)
		A[i] = static_cast <float> (rand()) / (static_cast <float> (RAND_MAX / n));
}


int main(int argc, char** argv)
{
	//int array_size = 10;


	float* A, *sum;
	srand(time(NULL));
	/*
	if (argc == 2)
	{
		array_size = strtof(argv[1], NULL);
	}
	else
		cout << "Ingrese array_size"; cin >> array_size;
	*/

	A = new float[array_size];
	sum = new float[1]{ 0 };

	GenVector(A, array_size);

	vecSum(A, sum);

	Imprimir(A, array_size);

	cout << "suma: " << sum[0];
	cout << "suma total:" << sumtotal;
	

	return 0;
}