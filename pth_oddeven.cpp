//Oddeven pthread c++

#include <iostream>
#include <pthread.h>
#include "timer.h"

using std::cout;
using std::cin;

#define MAX 1000

typedef struct
{
    int start;
    int end;
    int* arr;
} thread_data_t;

static bool g_swapped;
pthread_barrier_t barrier;
pthread_mutex_t mutex;

//Generar random data
int* GenerateData(int size)
{
    int* p = new int[size];
    for (int i = 0; i < size; ++i)
        p[i] = rand() % MAX;
    return p;
}

//Mostrar Data de arrays
void ShowData(int* p, int size)
{
    for (int i =0; i < size; ++i)
        cout << p[i] << " ";
}

void Swap(int* p, int i, int j)
{
    int tmp = p[i];
    p[i] = p[j];
    p[j] = tmp;
}

//Funcion para dar a cada thread su data a ordenar
void* thread(void* arg)
{
    int loc_start = ((thread_data_t*)arg)->start;
    int loc_end = ((thread_data_t*)arg)->end;
    int* loc_arr = ((thread_data_t*)arg)->arr;

    bool swapped;
    
    do
    {
        //Esperar que todos los thread hayan sido creados
        pthread_barrier_wait(&barrier);
        g_swapped = false;
        swapped = false;

        //Odd
        for (int i = loc_start + 1; i < loc_end; i+= 2)
        {
            if (loc_arr[i] > loc_arr[i+1])
            {
                //Swap(loc_arr, i, i+1);
                int temp = loc_arr[i];
                loc_arr[i] = loc_arr[i + 1];
                loc_arr[i + 1] = temp;
                swapped = 1;
                swapped = true;
            }
        }
        pthread_barrier_wait(&barrier);
        //Esperar a que se procesen todos los Odd
        //Even
        for (int i = loc_start; i < loc_end - 1; i +=2)
        {
            if (loc_arr[i] > loc_arr[i+1])
            {
                //Swap(loc_arr, i, i+1);
                int temp = loc_arr[i];
                loc_arr[i] = loc_arr[i + 1];
                loc_arr[i + 1] = temp;
                swapped = 1;
                swapped = true;
            }
        }

        //Avisar a threads si hubo algun swap
        pthread_mutex_lock(&mutex);
        g_swapped = swapped | g_swapped;
        pthread_mutex_unlock(&mutex);

        pthread_barrier_wait(&barrier);
        //Esperar a los threads por even
    } while (g_swapped); //Repetir mientras haya swap
    
    pthread_exit(NULL);
}

//Odd even sort
void OddEven(int thread_count, int* p, int size)
{
    int frac = size/thread_count;

    pthread_barrier_init(&barrier, NULL, thread_count);
    pthread_t threads[thread_count];

    for (int i = 0; i < thread_count; ++i)
    {
        thread_data_t* thread_data = new thread_data_t[sizeof(thread_data_t)];
        int slice = i * frac;
        if (slice % 2 == 1) //inicio impar
        {
            thread_data->start = slice -1; 
        }
        else //inicio par
        {
            thread_data->start = slice;
        }
        thread_data->end = slice + frac +1;
        thread_data->arr = p;
        pthread_create(&threads[i], NULL, thread, (void*) thread_data);     
    }

    for (int i =0; i < thread_count; ++i)
        pthread_join(threads[i], NULL);
    
    pthread_barrier_destroy(&barrier);
}

int main()
{
    int size_arr;
    int thr;
    double start, finish;

    cout << "Cuanta data? "; cin >> size_arr;
    cout << "Threads? "; cin >> thr;

    int* p = GenerateData(size_arr);

    //cout << "Original\n";
    //ShowData(p, size_arr);
    GET_TIME(start);
    OddEven(thr, p, size_arr);
    GET_TIME(finish);

    cout << "Elapsed time" << finish - start << "seconds\n";

    //cout << "Ordenada\n";
    //ShowData(p, size_arr);

    delete p;
}