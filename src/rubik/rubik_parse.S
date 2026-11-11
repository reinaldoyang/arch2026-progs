    .section .text.parse_target,"ax",@progbits
    .option norvc
    .globl rubik_parse_ranks
    .type rubik_parse_ranks, @function

/*
 * a0: pointer to a NUL-terminated 14-character cube state
 * returns a0 = 1, a1 = permutation rank, a2 = orientation rank on success
 * returns a0 = 0 on invalid length, digit, duplicate, or orientation sum
 *
 * The first seven parsed permutation values are kept in this function's
 * fixed 16-byte stack frame.  No heap, multiplication, division, or remainder
 * operation is used.
 */
rubik_parse_ranks:
    addi sp, sp, -16
    mv t0, a0                    /* input cursor */
    li t1, 0                     /* character index */
    li t2, 0                     /* seen-cubie bit mask */

.Lparse_permutation:
    lbu t3, 0(t0)
    li t4, '1'
    bltu t3, t4, .Lparse_failed
    li t5, '8'
    bgeu t3, t5, .Lparse_failed
    addi t3, t3, -'1'           /* internal cubie value 0..6 */
    li t4, 1
    sll t4, t4, t3
    and t5, t2, t4
    bnez t5, .Lparse_failed
    or t2, t2, t4
    add t5, sp, t1
    sb t3, 0(t5)
    addi t0, t0, 1
    addi t1, t1, 1
    li t4, 7
    bltu t1, t4, .Lparse_permutation
    li t3, 0x7f
    bne t2, t3, .Lparse_failed

    li t1, 0                     /* orientation index */
    li t2, 0                     /* orientation sum */
    li a2, 0                     /* orientation rank */
.Lparse_orientation:
    lbu t3, 0(t0)
    li t4, '1'
    bltu t3, t4, .Lparse_failed
    li t5, '4'
    bgeu t3, t5, .Lparse_failed
    addi t3, t3, -'1'           /* internal orientation 0..2 */
    add t2, t2, t3
    li t4, 6
    bgeu t1, t4, .Lparse_orientation_ranked
    slli t4, a2, 1
    add a2, t4, a2              /* rank *= 3 */
    add a2, a2, t3
.Lparse_orientation_ranked:
    addi t0, t0, 1
    addi t1, t1, 1
    li t4, 7
    bltu t1, t4, .Lparse_orientation

    /* Requiring NUL here enforces exactly 14 input characters. */
    lbu t3, 0(t0)
    bnez t3, .Lparse_failed

    /* Check orientation_sum modulo 3 by bounded subtraction. */
    li t3, 3
.Lparse_orientation_sum:
    bltu t2, t3, .Lparse_orientation_sum_ready
    addi t2, t2, -3
    j .Lparse_orientation_sum
.Lparse_orientation_sum_ready:
    bnez t2, .Lparse_failed

    /* Rank the permutation from its Lehmer digits using small radices. */
    li a1, 0
    li t0, 0                     /* permutation index */
.Lrank_permutation_digit:
    add t1, sp, t0
    lbu t1, 0(t1)               /* current cubie */
    li t2, 0                     /* smaller cubies after this position */
    addi t3, t0, 1
.Lrank_count_smaller:
    li t4, 7
    bgeu t3, t4, .Lrank_digit_ready
    add t4, sp, t3
    lbu t4, 0(t4)
    bgeu t4, t1, .Lrank_not_smaller
    addi t2, t2, 1
.Lrank_not_smaller:
    addi t3, t3, 1
    j .Lrank_count_smaller

.Lrank_digit_ready:
    beqz t0, .Lrank_first_digit
    li t3, 7
    sub t3, t3, t0              /* radix: 6, 5, 4, 3, or 2 */
    mv t4, a1
    li a1, 0
.Lrank_small_multiply:
    add a1, a1, t4
    addi t3, t3, -1
    bnez t3, .Lrank_small_multiply
    add a1, a1, t2
    j .Lrank_next_digit
.Lrank_first_digit:
    mv a1, t2
.Lrank_next_digit:
    addi t0, t0, 1
    li t1, 6
    bltu t0, t1, .Lrank_permutation_digit

    li a0, 1
    addi sp, sp, 16
    ret

.Lparse_failed:
    li a0, 0
    li a1, 0
    li a2, 0
    addi sp, sp, 16
    ret

    .size rubik_parse_ranks, .-rubik_parse_ranks
