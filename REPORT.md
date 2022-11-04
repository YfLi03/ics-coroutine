---
姓名: 李轶凡
学号: 2021011042
班级: 计16
---

# 协程实验报告

## Task 1:

#### 代码填写：

```cpp
void yield() {
  if (!g_pool->is_parallel) {
    // 从 g_pool 中获取当前协程状态
    // 通过当前协程池的 context_id 来确定目前处在的协程，因此每次切换协程时需要修改 context_id
    auto context = g_pool->coroutines[g_pool->context_id];
    // 调用 coroutine_switch 切换到 coroutine_pool 上下文
    // 暂停当前协程，回到（负责切换协程的）父函数，因此参数中前者是 callee, 后者是 caller
    coroutine_switch(context->callee_registers, context->caller_registers);
  }
}
```

```cpp
virtual void resume() {
// 调用 coroutine_switch
    coroutine_switch(caller_registers, callee_registers);
// 在汇编中保存 callee-saved 寄存器，设置协程函数栈帧，然后将 rip 恢复到协程 yield 之后所需要执行的指令地址。
// 当前函数所处环境即为 caller 。看似处在一个子函数里，但切换回当前环境后，下一句语句即为执行返回，回到负责调度协程的父函数。
}
```

```assembly
.global coroutine_switch
coroutine_switch:
    # TODO: Task 1
    # 保存 callee-saved 寄存器到 %rdi 指向的上下文
    # 由于调用 yield 和 coroutine_switch 仍然是调用函数的样子，因此 caller_saved regs 会在进入 coroutine_switch 前被保存在栈上，无需手动保存。
    movq  %rsp, 64(%rdi)
    movq  %rbx, 72(%rdi)
    movq  %rbp, 80(%rdi)
    movq  %r12, 88(%rdi)
    movq  %r13, 96(%rdi)
    movq  %r14, 104(%rdi)
    movq  %r15, 112(%rdi)

    # 保存的上下文中 rip 指向 ret 指令的地址（.coroutine_ret）
    # 使用 %rbx 作为临时寄存器完成这一操作
    leaq .coroutine_ret(%rip), %rbx
    movq  %rbx, 120(%rdi)


    # 从 %rsi 指向的上下文恢复 callee-saved 寄存器
    movq  64(%rsi),  %rsp
    movq  72(%rsi), %rbx
    movq  80(%rsi), %rbp
    movq  88(%rsi),  %r12
    movq  96(%rsi),  %r13
    movq  104(%rsi),  %r14
    movq  112(%rsi),  %r15

    jmpq  *120(%rsi)
    # 最后 jmpq 到上下文保存的 rip
    # 虽然难以直接修改 %rip 寄存器，但是可以使用 jmpq 跳转到应该去往的地址。大部分情况下执行的就是 ret 语句，但是当初次访问一些协程的时候我们访问的是 coroutine_entry 而非 .coroutine_ret， 因此在这里不能直接写 ret. 
```

对于 `void serial_execute_all()` 函数中填空内容， Task2 所实现的功能为 Task1 的超集，因此留待后文解释，此处不作赘述。

#### 阅读要求：

```cpp
// TODO: Task 1
// 在实验报告中分析以下代码
void coroutine_main(struct basic_context *context) {
  context->run();
  context->finished = true;
  coroutine_switch(context->callee_registers, context->caller_registers);

  // unreachable
  assert(false);
}
```
第一次（ 使用 context_switch ) 进入某一协程时会调用 coroutine_entry, coroutine_entry 会调用 coroutine_main，这是正常情况下 coroutine_main 唯一一次被调用。
被调用后， coroutine_main 会调用具体要执行的函数的 run() 函数，记为 func 。

- 如果 func 函数在执行过程中 yield() 了，存储的上下文就是 func 函数中的上下文。之后再次进入该协程时，直接回直接回到 func 函数内部，不会涉及 coroutine_main 。
- func 函数执行完毕后，执行 ret, 返回到 coroutine_main 函数中。

返回到 coroutine_main 后，执行的下一句语句就是 context->finished = true，这是合理的（因为具体的函数已经执行完毕了）。接下来会用 context_switch 切换回进入 coroutine_entry 之前的环境（一般情况也就是负责线程调度的父函数）。此后，这一已经被标为 finished 的协程将不再被访问，因此下一语句 assert(false) 自然是 unreachable 的。


```cpp
// TODO: Task 1
    // 在实验报告中分析以下代码
    // 对齐到 16 字节边界
    uint64_t rsp = (uint64_t)&stack[stack_size - 1];
    rsp = rsp - (rsp & 0xF);

    void coroutine_main(struct basic_context * context);

    callee_registers[(int)Registers::RSP] = rsp;
    // 协程入口是 coroutine_entry
    callee_registers[(int)Registers::RIP] = (uint64_t)coroutine_entry;
    // 设置 r12 寄存器为 coroutine_main 的地址
    callee_registers[(int)Registers::R12] = (uint64_t)coroutine_main;
    // 设置 r13 寄存器，用于 coroutine_main 的参数
    callee_registers[(int)Registers::R13] = (uint64_t)this;
```

进入一个协程有且只有上下文切换 (coroutine_switch) 一种方法。对于恢复被 yield 的协程，这是很自然的想法。但是对于一个还没有被执行过的协程，这样的做法会显得比较困难，要求我们预先配置好协程的上下文（也就是寄存器）。这段代码起到了这一作用。

rsp 是（协程的）栈指针。对于每个协程，它实际指向堆上的一块足够大的空间空间，以此来模拟协程的栈。 `rsp & 0xF` 操作保证了栈是 16 字节对齐的，以免引发段错误。

除了 rsp 以外，这段代码还初始化了以下的“寄存器”：
- rdi 被设置为 coroutine_entry。
- r12 r13 分别为 coroutine_main 函数以及其参数，供 coroutine_entry 调用。

为什么要多 coroutine_entry 这样一层嵌套调用呢？

