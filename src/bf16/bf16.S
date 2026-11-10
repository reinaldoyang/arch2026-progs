# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    srli    t0, a0, 23
    andi    t0, t0, 0xff
    li      t1, 0xff
    beq     t0, t1, .Lfrom_shift
    srli    t0, a0, 16
    andi    t0, t0, 1
    li      t1, 0x7fff
    add     t1, t1, t0
    add     a0, a0, t1
.Lfrom_shift:
    srli    a0, a0, 16
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    xor     t0, a0, a1
    li      a2, 0x8000
    and     t0, t0, a2              # result sign
    srli    t1, a0, 7
    andi    t1, t1, 0xff            # exponent a
    srli    t2, a1, 7
    andi    t2, t2, 0xff            # exponent b
    andi    t3, a0, 0x7f            # fraction/significand a
    andi    t4, a1, 0x7f            # fraction/significand b

    # Special operands are handled in the contract's required order.
    li      a2, 0xff
    beq     t1, a2, .Lmul_special_a
    beq     t2, a2, .Lmul_special_b
    slli    a2, a0, 17
    beqz    a2, .Lmul_return_sign
    slli    a2, a1, 17
    beqz    a2, .Lmul_return_sign

    # Normalize denormals, or insert the hidden bit for normal operands.
    beqz    t1, .Lmul_denorm_a
    ori     t3, t3, 0x80
    j       .Lmul_prepare_b
.Lmul_denorm_a:
    li      t1, 1
.Lmul_norm_a:
    andi    a2, t3, 0x80
    bnez    a2, .Lmul_prepare_b
    slli    t3, t3, 1
    addi    t1, t1, -1
    j       .Lmul_norm_a

.Lmul_prepare_b:
    beqz    t2, .Lmul_denorm_b
    ori     t4, t4, 0x80
    j       .Lmul_product
.Lmul_denorm_b:
    li      t2, 1
.Lmul_norm_b:
    andi    a2, t4, 0x80
    bnez    a2, .Lmul_product
    slli    t4, t4, 1
    addi    t2, t2, -1
    j       .Lmul_norm_b

    # Multiply the two eight-bit significands without the M extension.
.Lmul_product:
    li      a3, 0
    mv      a4, t3
    mv      a5, t4
.Lmul_product_loop:
    beqz    a5, .Lmul_scale
    andi    a2, a5, 1
    beqz    a2, .Lmul_product_shift
    add     a3, a3, a4
.Lmul_product_shift:
    slli    a4, a4, 1
    srli    a5, a5, 1
    j       .Lmul_product_loop

.Lmul_scale:
    add     a6, t1, t2
    addi    a6, a6, -127            # result exponent
    srli    a3, a3, 7               # result significand
    andi    a2, a3, 0x100
    beqz    a2, .Lmul_range
    srli    a3, a3, 1
    addi    a6, a6, 1

.Lmul_range:
    li      a2, 0xff
    bge     a6, a2, .Lmul_return_inf
    bge     zero, a6, .Lmul_underflow
    slli    a6, a6, 7
    andi    a3, a3, 0x7f
    or      a0, t0, a6
    or      a0, a0, a3
    ret

.Lmul_underflow:
    li      a2, -6
    blt     a6, a2, .Lmul_return_sign
    andi    a2, a3, 0x7f
    li      a3, 1
    sub     a3, a3, a6
    srl     a2, a2, a3
    or      a0, t0, a2
    ret

.Lmul_special_a:
    bnez    t3, .Lmul_return
    slli    a2, a1, 17
    beqz    a2, .Lmul_return_nan
    j       .Lmul_return_inf

.Lmul_special_b:
    bnez    t4, .Lmul_return_b
    slli    a2, a0, 17
    beqz    a2, .Lmul_return_nan
.Lmul_return_inf:
    li      a2, 0x7f80
    or      a0, t0, a2
    ret
.Lmul_return_nan:
    li      a0, 0x7fc0
    ret
.Lmul_return_sign:
    mv      a0, t0
.Lmul_return:
    ret
.Lmul_return_b:
    mv      a0, a1
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    srli    t0, a0, 7
    andi    t0, t0, 0xff            # exponent
    andi    t1, a0, 0x7f            # fraction

    li      a1, 0xff
    beq     t0, a1, .Lsqrt_special
    slli    a1, a0, 16
    bltz    a1, .Lsqrt_negative
    beqz    t0, .Lsqrt_zero

    ori     t2, t1, 0x80            # significand
    andi    a1, t0, 1
    bnez    a1, .Lsqrt_odd_exp
    slli    t2, t2, 1
    srli    t3, t0, 1
    addi    t3, t3, 63              # result exponent
    j       .Lsqrt_search_init
.Lsqrt_odd_exp:
    srli    t3, t0, 1
    addi    t3, t3, 64

    # Binary-search for the largest root whose scaled square is no larger
    # than the input significand.
.Lsqrt_search_init:
    li      t4, 90                   # low
    li      t5, 256                  # high
    li      t6, 90                   # best root
.Lsqrt_search:
    bltu    t5, t4, .Lsqrt_normalize
    add     a1, t4, t5
    srli    a1, a1, 1               # mid

    li      a2, 0                   # mid * mid
    mv      a3, a1
    mv      a4, a1
.Lsqrt_square_loop:
    beqz    a4, .Lsqrt_square_done
    andi    a5, a4, 1
    beqz    a5, .Lsqrt_square_shift
    add     a2, a2, a3
.Lsqrt_square_shift:
    slli    a3, a3, 1
    srli    a4, a4, 1
    j       .Lsqrt_square_loop
.Lsqrt_square_done:
    srli    a2, a2, 7
    bltu    t2, a2, .Lsqrt_too_large
    mv      t6, a1
    addi    t4, a1, 1
    j       .Lsqrt_search
.Lsqrt_too_large:
    addi    t5, a1, -1
    j       .Lsqrt_search

.Lsqrt_normalize:
    li      a1, 256
    bltu    t6, a1, .Lsqrt_check_low
    srli    t6, t6, 1
    addi    t3, t3, 1
    j       .Lsqrt_range
.Lsqrt_check_low:
    li      a1, 128
    bgeu    t6, a1, .Lsqrt_range
    slli    t6, t6, 1
    addi    t3, t3, -1

.Lsqrt_range:
    li      a1, 0xff
    bge     t3, a1, .Lsqrt_inf
    bge     zero, t3, .Lsqrt_zero
    slli    t3, t3, 7
    andi    t6, t6, 0x7f
    or      a0, t3, t6
    ret

.Lsqrt_special:
    bnez    t1, .Lsqrt_return
    slli    a1, a0, 16
    bltz    a1, .Lsqrt_nan
    ret
.Lsqrt_negative:
    # Discard the sign bit and test the remaining 15-bit magnitude.
    slli    a1, a0, 17
    beqz    a1, .Lsqrt_zero
.Lsqrt_nan:
    li      a0, 0x7fc0
    ret
.Lsqrt_inf:
    li      a0, 0x7f80
    ret
.Lsqrt_zero:
    li      a0, 0
.Lsqrt_return:
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
