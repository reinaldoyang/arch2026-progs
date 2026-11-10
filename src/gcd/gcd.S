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
.Lgcd_common:
    or      t1, a0, a1
    andi    t1, t1, 1
    bnez    t1, .Lgcd_make_a_odd
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    t0, t0, 1
    j       .Lgcd_common

    # Keep a odd. Each iteration then removes powers of two from b,
    # orders the operands, and replaces the larger one by their difference.
.Lgcd_make_a_odd:
    andi    t1, a0, 1
    bnez    t1, .Lgcd_make_b_odd
    srli    a0, a0, 1
    j       .Lgcd_make_a_odd

.Lgcd_make_b_odd:
    andi    t1, a1, 1
    bnez    t1, .Lgcd_order
    srli    a1, a1, 1
    j       .Lgcd_make_b_odd

.Lgcd_order:
    bgeu    a1, a0, .Lgcd_subtract
    mv      t1, a0
    mv      a0, a1
    mv      a1, t1
.Lgcd_subtract:
    sub     a1, a1, a0
    bnez    a1, .Lgcd_make_b_odd

    sll     a0, a0, t0
.Lgcd_return:
    ret
.Lgcd_return_b:
    mv      a0, a1
    ret
    .size   gcd_u32_asm, .-gcd_u32_asm
