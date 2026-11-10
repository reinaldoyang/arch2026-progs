# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beqz    a0, .Lgcd_return_b
    beqz    a1, .Lgcd_return

    # Remove powers of two shared by both operands.
    li      t0, 0
    or      t1, a0, a1
    andi    t1, t1, 1
    bnez    t1, .Lgcd_make_a_odd
.Lgcd_common:
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    t0, t0, 1
    or      t1, a0, a1
    andi    t1, t1, 1
    beqz    t1, .Lgcd_common

    # Keep a odd. Each iteration then removes powers of two from b,
    # orders the operands, and replaces the larger one by their difference.
.Lgcd_make_a_odd:
    andi    t1, a0, 1
    bnez    t1, .Lgcd_make_b_odd
.Lgcd_shift_a:
    srli    a0, a0, 1
    andi    t1, a0, 1
    beqz    t1, .Lgcd_shift_a

.Lgcd_make_b_odd:
    andi    t1, a1, 1
    bnez    t1, .Lgcd_order
.Lgcd_shift_b:
    srli    a1, a1, 1
    andi    t1, a1, 1
    beqz    t1, .Lgcd_shift_b

.Lgcd_order:
    bltu    a1, a0, .Lgcd_swap
    sub     a1, a1, a0
    bnez    a1, .Lgcd_shift_b

    sll     a0, a0, t0
.Lgcd_return:
    ret
.Lgcd_swap:
    sub     t1, a0, a1
    mv      a0, a1
    mv      a1, t1
    j       .Lgcd_shift_b
.Lgcd_return_b:
    mv      a0, a1
    ret
    .size   gcd_u32_asm, .-gcd_u32_asm
