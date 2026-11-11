# rubik_solve_asm: validate, search, and render a shortest RV32I solution.
    .text
    .option norvc
    .globl rubik_solve_asm
    .type rubik_solve_asm, @function
    .align 2
rubik_solve_asm:
    # metrics scratch at 0..55; move indices at 56..66.
    addi sp, sp, -128
    sw ra, 124(sp)
    sw s0, 120(sp)
    sw s1, 116(sp)
    sw s2, 112(sp)
    sw s3, 108(sp)
    mv s0, a1                   # output
    mv s1, a2                   # capacity
    call rubik_parse_ranks
    beqz a0, .Lrubik_invalid

    mv a0, a1                   # permutation rank
    mv a1, a2                   # orientation rank
    addi a2, sp, 56             # move-index array
    mv a3, sp                   # search metrics scratch
    call rubik_search_ranks
    beqz a0, .Lrubik_invalid
    lbu s3, 0(sp)               # number of moves
    addi s2, sp, 56

    # Count all move-name bytes, spaces, and the final NUL before writing.
    li t0, 1
    li t1, 0
.Lrubik_count:
    bgeu t1, s3, .Lrubik_check_capacity
    add t2, s2, t1
    lbu t2, 0(t2)
    addi t0, t0, 1              # face letter
    beqz t1, .Lrubik_count_suffix
    addi t0, t0, 1              # separating space
.Lrubik_count_suffix:
    beqz t2, .Lrubik_count_next
    li t3, 3
    beq t2, t3, .Lrubik_count_next
    li t3, 6
    beq t2, t3, .Lrubik_count_next
    addi t0, t0, 1              # 2 or apostrophe
.Lrubik_count_next:
    addi t1, t1, 1
    j .Lrubik_count

.Lrubik_check_capacity:
    bltu s1, t0, .Lrubik_small
    li t0, 0                    # output offset
    li t1, 0                    # move index
.Lrubik_render:
    bgeu t1, s3, .Lrubik_terminate
    beqz t1, .Lrubik_move
    add t3, s0, t0
    li t4, ' '
    sb t4, 0(t3)
    addi t0, t0, 1
.Lrubik_move:
    add t2, s2, t1
    lbu t2, 0(t2)
    li t3, 3
    bltu t2, t3, .Lrubik_face_r
    li t3, 6
    bltu t2, t3, .Lrubik_face_b
    li t4, 'D'
    addi t2, t2, -6
    j .Lrubik_store_face
.Lrubik_face_b:
    li t4, 'B'
    addi t2, t2, -3
    j .Lrubik_store_face
.Lrubik_face_r:
    li t4, 'R'
.Lrubik_store_face:
    add t3, s0, t0
    sb t4, 0(t3)
    addi t0, t0, 1
    beqz t2, .Lrubik_render_next
    li t4, '2'
    li t5, 1
    beq t2, t5, .Lrubik_store_suffix
    li t4, 39                  # apostrophe
.Lrubik_store_suffix:
    add t3, s0, t0
    sb t4, 0(t3)
    addi t0, t0, 1
.Lrubik_render_next:
    addi t1, t1, 1
    j .Lrubik_render

.Lrubik_terminate:
    add t3, s0, t0
    sb zero, 0(t3)
    mv a0, s3
    j .Lrubik_return
.Lrubik_small:
    beqz s1, .Lrubik_small_return
    sb zero, 0(s0)
.Lrubik_small_return:
    li a0, -2
    j .Lrubik_return
.Lrubik_invalid:
    li a0, -1
.Lrubik_return:
    lw s3, 108(sp)
    lw s2, 112(sp)
    lw s1, 116(sp)
    lw s0, 120(sp)
    lw ra, 124(sp)
    addi sp, sp, 128
    ret
    .size rubik_solve_asm, .-rubik_solve_asm
