#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

// Optional: use these functions to add debug or error prints to your application
#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

void* threadfunc(void* thread_param)
{

    // TODO: wait, obtain mutex, wait, release mutex as described by thread_data structure
    // hint: use a cast like the one below to obtain thread arguments from your parameter
    //struct thread_data* thread_func_args = (struct thread_data *) thread_param;

    struct thread_data *thread_data_params = (struct thread_data *)thread_param;

    if (thread_data_params != NULL) {

	thread_data_params->thread_complete_success = false;
        usleep(thread_data_params->sleep_time_ms*1000);

	pthread_mutex_lock(thread_data_params->lock);
	usleep(thread_data_params->hold_time_ms*1000);

        thread_data_params->thread_complete_success = true;
        pthread_mutex_unlock(thread_data_params->lock);
    } 

    return thread_param;
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,int wait_to_obtain_ms, int wait_to_release_ms)
{
    /**
     * TODO: allocate memory for thread_data, setup mutex and wait arguments, pass thread_data to created thread
     * using threadfunc() as entry point.
     *
     * return true if successful.
     *
     * See implementation details in threading.h file comment block
     */

    DEBUG_LOG("Starting thread");
    if (!mutex | !thread) {
        ERROR_LOG("Invalid mutex or thread ");
	return false;
    }

    struct thread_data *data = malloc(sizeof(struct thread_data));
    if (!data) {
        ERROR_LOG("Failed to allocate memory");
        return false;
    }

    DEBUG_LOG("Initializing the thread params");
    data->lock = mutex;
    data->hold_time_ms = wait_to_release_ms;
    data->sleep_time_ms = wait_to_obtain_ms;
    data->thread_complete_success = false;

    int ret = pthread_create(thread, NULL, threadfunc, data);

    if (ret != 0) {
        ERROR_LOG("Failed to create thread");
        free(data);
	return false;
    }

    DEBUG_LOG("Thread created successfully");
    return true;    
}

/*
int main() {
   const int NUM_THREADS = 3;
    pthread_t threads[NUM_THREADS];

    pthread_mutex_t mutex;
    pthread_mutex_init(&mutex, NULL);

    // Start threads
    for (int i = 0; i < NUM_THREADS; i++) {
        start_thread_obtaining_mutex(&threads[i], &mutex,
                                     100 * (i+1),   // wait before locking
                                     200 + 100*i);   // hold mutex
    }

    // Collect thread_data_t pointer from each thread
    for (int i = 0; i < NUM_THREADS; i++) {
        struct thread_data *data;
        pthread_join(threads[i], (void**)&data);

        if (data) {
            printf("Thread completed successfully: %s\n",
                   data->thread_complete_success ? "YES" : "NO");
            // Free the dynamically allocated thread_data_t
            free(data);
        } else {
            printf("Thread %d returned NULL\n", i+1);
        }
    }

    pthread_mutex_destroy(&mutex);
    return 0; 
}*/

