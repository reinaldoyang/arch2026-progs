"""Emit the assembly lookup for states at most five moves from solved.

This is a development-time generator. The RV32I solver uses only its generated
table and never calls Python or code from another repository.
"""

import pathlib
import re


source = pathlib.Path(__file__).with_name("rubik_tables.c").read_text()
arrays = {
    name: [int(value) for value in re.findall(r"\d+", body)]
    for name, body in re.findall(
        r"const uint\d+_t\s+(\w+)\[\d+\]\s*=\s*\{([^}]*)\}",
        source,
        re.S,
    )
}
permutation_turn = [arrays[f"idastar_permutation_turn_{face}"] for face in "rbd"]
orientation_turn = [arrays[f"idastar_orientation_turn_{face}"] for face in "rbd"]

distance = {(0, 0): 0}
frontier = [(0, 0)]
for depth in range(1, 6):
    following = []
    for permutation, orientation in frontier:
        for face in range(3):
            next_p, next_o = permutation, orientation
            for _ in range(3):
                next_p = permutation_turn[face][next_p]
                next_o = orientation_turn[face][next_o]
                state = (next_p, next_o)
                if state not in distance:
                    distance[state] = depth
                    following.append(state)
    frontier = following

assert len(distance) == 12224
by_permutation = [[] for _ in range(5040)]
for (permutation, orientation), depth in distance.items():
    by_permutation[permutation].append((orientation << 3) | depth)

offsets = [0]
entries = []
for bucket in by_permutation:
    entries.extend(sorted(bucket))
    offsets.append(len(entries))


def emit_values(values):
    for start in range(0, len(values), 16):
        print("+    .half " + ", ".join(str(value) for value in values[start:start + 16]))


print("*** Begin Patch")
print("*** Add File: src/rubik/rubik_near.S")
print("+/* Generated from the current repository's quarter-turn tables. */")
print("+    .section .rodata.rubik_near,\"a\",@progbits")
print("+    .balign 2")
print("+    .globl rubik_near_offsets")
print("+rubik_near_offsets:")
emit_values(offsets)
print("+    .globl rubik_near_entries")
print("+rubik_near_entries:")
emit_values(entries)
print("*** End Patch")
