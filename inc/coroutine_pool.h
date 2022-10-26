#pragma once
#include "context.h"
#include <memory>
#include <thread>
#include <vector>

struct coroutine_pool;
extern coroutine_pool *g_pool;

/**
 * @brief 协程池
 * 保存所有需要同步执行的协程函数。并可以进行并行/串行执行。
 */
struct coroutine_pool {
  std::vector<basic_context *> coroutines;
  int context_id;

  // whether run in threads or coroutines
  bool is_parallel;

  ~coroutine_pool() {
    for (auto context : coroutines) {
      delete context;
    }
  }

  // add coroutine to pool
  template <typename F, typename... Args>
  void new_coroutine(F f, Args... args) {
    coroutines.push_back(new coroutine_context(f, args...));
  }

  /**
   * @brief 以并行多线程的方式执行所有协程函数
   */
  void parallel_execute_all() {
    g_pool = this;
    is_parallel = true;
    std::vector<std::thread> threads;
    for (auto p : coroutines) {
      threads.emplace_back([p]() { p->run(); });
    }

    for (auto &thread : threads) {
      thread.join();
    }
  }

  /**
   * @brief 以协程执行的方式串行并同时执行所有协程函数
   * @b 何谓串行同时执行？
   * TODO: Task 1, Task 2
   * 在 Task 1 中，我们不需要考虑协程的 ready
   * 属性，即可以采用轮询的方式挑选一个未完成执行的协程函数进行继续执行的操作。
   * 在 Task 2 中，我们需要考虑 sleep 带来的 ready
   * 属性，需要对协程函数进行过滤，选择 ready 的协程函数进行执行。
   *
   * 当所有协程函数都执行完毕后，退出该函数。
   */
  void serial_execute_all() {
    is_parallel = false;
    g_pool = this;

    bool all_finished = false;
    while ( !all_finished ){
      all_finished = true;
      g_pool->context_id = 0;

      for (auto &context : coroutines) {
        if ( context == nullptr || context->finished ) {  
          delete context;
          context = nullptr;
        } else {
          if(context->ready || context->ready_func() ) { //the second will not be visited if ready is true
            context->ready = true;
            context->resume();
          }
          all_finished = false;
        }
        g_pool->context_id++;
      }

    }
    coroutines.clear();
  }
};
