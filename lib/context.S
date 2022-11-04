.global coroutine_entry
coroutine_entry:
    movq %r13, %rdi
    callq *%r12

.global coroutine_switch
coroutine_switch:
    # TODO: Task 1
    # 保存 callee-saved 寄存器到 %rdi 指向的上下文
    # 由于调用 yield 和 coroutine_switch 仍然是调用函数的样子，因此 caller_saved regs 无需手动保存。
    movq  %rsp, 64(%rdi)
    movq  %rbx, 72(%rdi)
    movq  %rbp, 80(%rdi)
    movq  %r12, 88(%rdi)
    movq  %r13, 96(%rdi)
    movq  %r14, 104(%rdi)
    movq  %r15, 112(%rdi)

    # 保存的上下文中 rip 指向 ret 指令的地址（.coroutine_ret）
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

.coroutine_ret:
    ret
