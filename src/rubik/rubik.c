#include "rubik.h"
#include "rubik_tables.h"

enum { CUBIES = 7, MAX_DEPTH = 11 };

struct frame {
    uint16_t permutation;
    uint16_t orientation;
    uint8_t face;
    uint8_t turn;
    uint8_t entered;
    uint8_t heuristic;
};

static const uint16_t *const permutation_turn[3] = {
    idastar_permutation_turn_r,
    idastar_permutation_turn_b,
    idastar_permutation_turn_d,
};
static const uint16_t *const orientation_turn[3] = {
    idastar_orientation_turn_r,
    idastar_orientation_turn_b,
    idastar_orientation_turn_d,
};

static uint16_t times_small(uint16_t value, unsigned factor)
{
    uint16_t result = 0;
    while (factor != 0) {
        if (factor & 1u)
            result = (uint16_t) (result + value);
        value = (uint16_t) (value << 1);
        factor >>= 1;
    }
    return result;
}

static int parse_ranks(const char *state,
                       uint16_t *permutation,
                       uint16_t *orientation)
{
    uint8_t cubie[CUBIES];
    unsigned seen = 0;
    unsigned sum = 0;
    uint16_t o_rank = 0;

    for (unsigned i = 0; i < CUBIES; i++) {
        unsigned digit = (unsigned) (uint8_t) state[i] - (unsigned) '1';
        if (digit >= CUBIES || (seen & (1u << digit)) != 0)
            return 0;
        cubie[i] = (uint8_t) digit;
        seen |= 1u << digit;
    }
    for (unsigned i = 0; i < CUBIES; i++) {
        unsigned digit =
            (unsigned) (uint8_t) state[CUBIES + i] - (unsigned) '1';
        if (digit >= 3)
            return 0;
        sum += digit;
        if (i < CUBIES - 1)
            o_rank = (uint16_t) ((o_rank << 1) + o_rank + digit);
    }
    if (state[2 * CUBIES] != '\0')
        return 0;
    while (sum >= 3)
        sum -= 3;
    if (sum != 0)
        return 0;

    uint16_t p_rank = 0;
    for (unsigned i = 0; i < CUBIES - 1; i++) {
        unsigned smaller = 0;
        for (unsigned j = i + 1; j < CUBIES; j++)
            smaller += cubie[j] < cubie[i];
        p_rank = (uint16_t) (times_small(p_rank, CUBIES - i) + smaller);
    }
    *permutation = p_rank;
    *orientation = o_rank;
    return 1;
}

static uint8_t heuristic(uint16_t permutation, uint16_t orientation)
{
    uint8_t p = idastar_permutation_pdb[permutation];
    uint8_t o = idastar_orientation_pdb[orientation];
    return p > o ? p : o;
}

/* IDA* searches complete depth + admissible-heuristic contours. */
static int search(uint16_t root_p, uint16_t root_o, uint8_t solution[MAX_DEPTH])
{
    struct frame stack[MAX_DEPTH + 1];
    uint8_t path[MAX_DEPTH];
    uint8_t path_face[MAX_DEPTH];
    uint8_t root_h = heuristic(root_p, root_o);
    unsigned threshold = root_h;

    while (threshold <= MAX_DEPTH) {
        unsigned depth = 0;
        unsigned next_threshold = 255;
        stack[0].permutation = root_p;
        stack[0].orientation = root_o;
        stack[0].heuristic = root_h;
        stack[0].entered = 0;

        for (;;) {
            struct frame *f = &stack[depth];
            if (!f->entered) {
                unsigned estimate = depth + f->heuristic;
                f->entered = 1;
                f->face = 0;
                f->turn = 0;
                if (estimate > threshold) {
                    if (estimate < next_threshold)
                        next_threshold = estimate;
                    if (depth == 0)
                        break;
                    depth--;
                    continue;
                }
                if (f->permutation == 0 && f->orientation == 0) {
                    for (unsigned i = 0; i < depth; i++)
                        solution[i] = path[i];
                    return (int) depth;
                }
                if (depth == MAX_DEPTH) {
                    depth--;
                    continue;
                }
            }

            if (depth != 0 && f->face == path_face[depth - 1]) {
                f->face++;
                f->turn = 0;
            }
            if (f->face == 3) {
                if (depth == 0)
                    break;
                depth--;
                continue;
            }

            unsigned face = f->face;
            unsigned turn = f->turn;
            uint16_t p = f->permutation;
            uint16_t o = f->orientation;
            f->turn++;
            if (f->turn == 3) {
                f->turn = 0;
                f->face++;
            }
            for (unsigned i = 0; i <= turn; i++) {
                p = permutation_turn[face][p];
                o = orientation_turn[face][o];
            }
            path[depth] = (uint8_t) ((face << 1) + face + turn);
            path_face[depth] = (uint8_t) face;
            stack[depth + 1].permutation = p;
            stack[depth + 1].orientation = o;
            stack[depth + 1].heuristic = heuristic(p, o);
            stack[depth + 1].entered = 0;
            depth++;
        }
        threshold = next_threshold;
    }
    return -1;
}

int rubik_solve(const char *state, char *out, size_t cap)
{
    uint16_t permutation, orientation;
    uint8_t solution[MAX_DEPTH];
    if (!parse_ranks(state, &permutation, &orientation))
        return -1;

    int moves = search(permutation, orientation, solution);
    if (moves < 0)
        return -1;

    size_t needed = 1;
    for (int i = 0; i < moves; i++) {
        unsigned move = solution[i];
        needed += (i != 0) + 1 + (move != 0 && move != 3 && move != 6);
    }
    if (needed > cap) {
        if (cap != 0)
            out[0] = '\0';
        return -2;
    }

    size_t pos = 0;
    for (int i = 0; i < moves; i++) {
        unsigned move = solution[i];
        unsigned face;
        if (i != 0)
            out[pos++] = ' ';
        if (move < 3) {
            face = 0;
        } else if (move < 6) {
            face = 1;
            move -= 3;
        } else {
            face = 2;
            move -= 6;
        }
        out[pos++] = "RBD"[face];
        if (move == 1)
            out[pos++] = '2';
        else if (move == 2)
            out[pos++] = '\'';
    }
    out[pos] = '\0';
    return moves;
}
