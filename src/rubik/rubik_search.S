    .section .text.rubik_search,"ax",@progbits
    .option norvc
    .globl rubik_search_ranks
    .type rubik_search_ranks, @function

/*
 * Search forward at most six moves. The compact reverse table gives the
 * exact distance for every state at most five moves from solved. Every
 * shortest solution (maximum length 11) crosses these two search regions.
 * a0/a1: ranks; a2: eleven output move bytes; a3: length byte at offset 0.
 */
rubik_search_ranks:
    addi sp, sp, -224
    sw ra, 172(sp)
    sw s0, 176(sp)
    sw s1, 180(sp)
    sw s2, 184(sp)
    sw s3, 188(sp)
    sw s4, 192(sp)
    sw s5, 196(sp)
    sw s6, 200(sp)
    sw s7, 204(sp)
    sw s8, 208(sp)
    sw s9, 212(sp)
    sw s10, 216(sp)
    sw s11, 220(sp)

    mv s2, sp                  /* seven eight-byte search frames */
    addi s3, sp, 64            /* current path */
    addi s4, sp, 80            /* face of each current move */
    addi s5, sp, 96            /* best prefix */
    mv s6, a2                  /* caller's move array */
    mv s7, a3                  /* caller's length byte */
    la s8, .Lturn_table_pairs
    la s9, rubik_asm_permutation_pdb
    la s10, rubik_asm_orientation_pdb
    la s11, rubik_near_offsets
    la a6, rubik_near_entries
    sh a0, 0(s2)
    sh a1, 2(s2)
    li t0, 1
    sb zero, 6(s2)
    add t1, s9, a0
    lbu t1, 0(t1)
    add t2, s10, a1
    lbu t2, 0(t2)
    bgeu t1, t2, .Lroot_h
    mv t1, t2
.Lroot_h:
    sb t1, 7(s2)
    li s0, 0                   /* forward depth */
    li s1, 12                  /* best length: none yet */

.Ldfs:
    slli t0, s0, 3
    add t0, s2, t0
    lbu t1, 6(t0)
    bnez t1, .Lexpanded

    li t1, 1
    sb t1, 6(t0)
    sb zero, 4(t0)
    sb zero, 5(t0)
    lbu t1, 7(t0)
    add t1, t1, s0
    bgeu t1, s1, .Lpop         /* the PDB lower bound cannot improve best */

    lhu a0, 0(t0)
    lhu a1, 2(t0)
    jal ra, .Lnear_lookup
    li t1, 255
    beq a0, t1, .Lnot_near

    add t1, s0, a0
    bgeu t1, s1, .Lpop
    mv s1, t1
    sh a0, 120(sp)             /* exact reverse distance */
    slli t0, s0, 3
    add t0, s2, t0
    lhu t1, 0(t0)
    sh t1, 116(sp)             /* meeting permutation */
    lhu t1, 2(t0)
    sh t1, 118(sp)             /* meeting orientation */
    li t1, 0
.Lcopy_best:
    bgeu t1, s0, .Lpop
    add t2, s3, t1
    lbu t2, 0(t2)
    add t3, s5, t1
    sb t2, 0(t3)
    addi t1, t1, 1
    j .Lcopy_best

.Lnot_near:
    addi t1, s0, 6             /* a table miss needs at least six more moves */
    bgeu t1, s1, .Lpop
    slli t0, s0, 3
    add t0, s2, t0
    j .Lexpanded

.Lpop:
    beqz s0, .Lsearch_done
    addi s0, s0, -1
    j .Ldfs

.Lexpanded:
    lbu t1, 4(t0)              /* next face */
    beqz s0, .Lface_ready
    addi t2, s0, -1
    add t2, s4, t2
    lbu t2, 0(t2)
    bne t1, t2, .Lface_ready
    addi t1, t1, 1
    sb t1, 4(t0)
    sb zero, 5(t0)
.Lface_ready:
    li t2, 3
    beq t1, t2, .Lpop

    lbu t2, 5(t0)              /* next turn: 0, 1, 2 */
    addi t3, t2, 1
    li t4, 3
    bne t3, t4, .Lstore_turn
    sb zero, 5(t0)
    addi t4, t1, 1
    sb t4, 4(t0)
    j .Lselect_tables
.Lstore_turn:
    sb t3, 5(t0)

.Lselect_tables:
    slli t4, t1, 3
    add t4, s8, t4
    lw t5, 0(t4)
    lw t4, 4(t4)
    lhu a0, 0(t0)
    lhu a1, 2(t0)
.Lapply_turn:
    slli a2, a0, 1
    add a2, t5, a2
    lhu a0, 0(a2)
    slli a2, a1, 1
    add a2, t4, a2
    lhu a1, 0(a2)
    addi t3, t3, -1
    bnez t3, .Lapply_turn

    slli t3, t1, 1
    add t3, t3, t1
    add t3, t3, t2
    add t4, s3, s0
    sb t3, 0(t4)
    add t4, s4, s0
    sb t1, 0(t4)

    addi t0, t0, 8
    sh a0, 0(t0)
    sh a1, 2(t0)
    add t3, s9, a0
    lbu t3, 0(t3)
    add t4, s10, a1
    lbu t4, 0(t4)
    bgeu t3, t4, .Lchild_h
    mv t3, t4
.Lchild_h:
    sb zero, 6(t0)
    sb t3, 7(t0)
    addi s0, s0, 1
    j .Ldfs

.Lsearch_done:
    li t0, 12
    beq s1, t0, .Lfailure
    lhu s4, 120(sp)            /* reverse distance */
    sub s0, s1, s4             /* best prefix length */
    li t0, 0
.Lcopy_prefix:
    bgeu t0, s0, .Lsuffix_start
    add t1, s5, t0
    lbu t1, 0(t1)
    add t2, s6, t0
    sb t1, 0(t2)
    addi t0, t0, 1
    j .Lcopy_prefix

.Lsuffix_start:
    lhu s2, 116(sp)            /* current permutation */
    lhu s3, 118(sp)            /* current orientation */
    mv s5, s0                  /* output index */
.Lsuffix:
    beqz s4, .Lsuccess
    li a5, 0                   /* face */
.Lsuffix_face:
    slli t0, a5, 3
    add t0, s8, t0
    lw a3, 0(t0)
    lw a2, 4(t0)
    mv s9, s2                  /* candidate permutation */
    mv s10, s3                 /* candidate orientation */
    li a4, 0                   /* turn */
.Lsuffix_turn:
    slli t0, s9, 1
    add t0, a3, t0
    lhu s9, 0(t0)
    slli t0, s10, 1
    add t0, a2, t0
    lhu s10, 0(t0)
    mv a0, s9
    mv a1, s10
    jal ra, .Lnear_lookup
    addi t0, s4, -1
    beq a0, t0, .Lsuffix_found
    addi a4, a4, 1
    li t0, 3
    bne a4, t0, .Lsuffix_turn
    addi a5, a5, 1
    li t0, 3
    bne a5, t0, .Lsuffix_face
    j .Lfailure               /* impossible for a valid reverse distance */

.Lsuffix_found:
    slli t0, a5, 1
    add t0, t0, a5
    add t0, t0, a4
    add t1, s6, s5
    sb t0, 0(t1)
    mv s2, s9
    mv s3, s10
    addi s4, s4, -1
    addi s5, s5, 1
    j .Lsuffix

.Lsuccess:
    sb s1, 0(s7)
    li a0, 1
    j .Lreturn
.Lfailure:
    li a0, 0
.Lreturn:
    lw ra, 172(sp)
    lw s0, 176(sp)
    lw s1, 180(sp)
    lw s2, 184(sp)
    lw s3, 188(sp)
    lw s4, 192(sp)
    lw s5, 196(sp)
    lw s6, 200(sp)
    lw s7, 204(sp)
    lw s8, 208(sp)
    lw s9, 212(sp)
    lw s10, 216(sp)
    lw s11, 220(sp)
    addi sp, sp, 224
    ret

/* a0=permutation, a1=orientation; return exact distance or 255. */
.Lnear_lookup:
    slli t0, a0, 1
    add t0, s11, t0
    lhu t1, 0(t0)
    lhu t2, 2(t0)
.Lnear_loop:
    bgeu t1, t2, .Lnear_miss
    slli t0, t1, 1
    add t0, a6, t0
    lhu t4, 0(t0)
    srli t3, t4, 3
    beq t3, a1, .Lnear_found
    bltu a1, t3, .Lnear_miss
    addi t1, t1, 1
    j .Lnear_loop
.Lnear_found:
    andi a0, t4, 7
    ret
.Lnear_miss:
    li a0, 255
    ret

    .size rubik_search_ranks, .-rubik_search_ranks

    .section .rodata.rubik_search_tables,"a",@progbits
    .balign 4
.Lturn_table_pairs:
    .word rubik_asm_permutation_turn_r
    .word rubik_asm_orientation_turn_r
    .word rubik_asm_permutation_turn_b
    .word rubik_asm_orientation_turn_b
    .word rubik_asm_permutation_turn_d
    .word rubik_asm_orientation_turn_d
