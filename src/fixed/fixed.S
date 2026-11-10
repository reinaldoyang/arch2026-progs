# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li      t0, 0
.Lop1_loop:
    beqz    a1, .Lop1_done
    and     t1, a0, a1
    slli    t1, t1, 1
    xor     a0, a0, a1
    mv      a1, t1
    addi    t0, t0, 1
    j       .Lop1_loop
.Lop1_done:
    sw      t0, 0(a2)
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and     t0, a0, a1
    xor     t1, a0, a1
    srli    t1, t1, 1
    add     a0, t0, t1
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    # Record the result sign and form unsigned magnitudes. This also handles
    # INT32_MIN because the magnitudes are kept as unsigned bit patterns.
    xor     t6, a0, a1
    srli    t6, t6, 31
    mv      t0, a0                  # shifted low word
    bgez    a0, .Lqmul_a_abs
    sub     t0, zero, t0
.Lqmul_a_abs:
    mv      t1, a1                  # multiplier
    bgez    a1, .Lqmul_b_abs
    sub     t1, zero, t1
.Lqmul_b_abs:
    li      t2, 0                   # product low word
    li      t3, 0                   # product high word
    li      t4, 0                   # shifted high word

    # Unsigned 32-by-32 shift-and-add multiplication into t3:t2.
.Lqmul_loop:
    beqz    t1, .Lqmul_signed
    andi    t5, t1, 1
    beqz    t5, .Lqmul_shift
    mv      a2, t2
    add     t2, t2, t0
    sltu    a2, t2, a2
    add     t3, t3, t4
    add     t3, t3, a2
.Lqmul_shift:
    srli    a2, t0, 31
    slli    t4, t4, 1
    or      t4, t4, a2
    slli    t0, t0, 1
    srli    t1, t1, 1
    j       .Lqmul_loop

    # Apply the sign to the full 64-bit product.
.Lqmul_signed:
    beqz    t6, .Lqmul_round
    sub     t2, zero, t2
    not     t3, t3
    seqz    a2, t2
    add     t3, t3, a2

    # Add half an output unit, then take bits 20..51. The low 32 bits of
    # that shifted value are the wrapping Q11.20 result.
.Lqmul_round:
    mv      a2, t2
    li      t5, 0x80000
    add     t2, t2, t5
    sltu    a2, t2, a2
    add     t3, t3, a2
    srli    t2, t2, 20
    slli    t3, t3, 12
    or      a0, t2, t3
    ret
    .size   q_mul_asm, .-q_mul_asm
