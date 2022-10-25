.global coroutine_entry
coroutine_entry:
    movq %r13, %rdi
    callq *%r12

.global coroutine_switch
coroutine_switch:
    # TODO: Task 1
    # 保存 callee-saved 寄存器到 %rdi 指向的上下文
    # 由于调用 yield 和 coroutine_switch 仍然是调用函数的样子，因此 caller_saved regs 无需手动保存。
    # Question: What to do with rsp?
    movq  %rsp, 8(%rdi)
    movq  %rbx, 88(%rdi)
    movq  %rbp, 96(%rdi)
    movq  %r12, 104(%rdi)
    movq  %r13, 112(%rdi)
    movq  %r14, 120(%rdi)
    movq  %r15, 128(%rdi)

    # 保存的上下文中 rip 指向 ret 指令的地址（.coroutine_ret）
    leaq  (%rip), %rbx
    movq  %rbx, 136(%rdi)


    # 从 %rsi 指向的上下文恢复 callee-saved 寄存器
    movq  8(%rsi),  %rsp
    movq  88(%rdi), %rbx
    movq  96(%rdi), %rbp
    movq  104(%rdi),  %r12
    movq  112(%rdi),  %r13
    movq  120(%rdi),  %r14
    movq  128(%rdi),  %r15


    jmpq  136(%rsi)
    # 最后 jmpq 到上下文保存的 rip
    # 为什么 不可以直接 ret 吗

.coroutine_ret:
    ret
