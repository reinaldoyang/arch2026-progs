#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;

    while (b != 0) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        passes++;
    }

    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t ua = (uint32_t) a;
    uint32_t ub = (uint32_t) b;
    uint32_t multiplicand = a < 0 ? 0u - ua : ua;
    uint32_t multiplier = b < 0 ? 0u - ub : ub;
    uint32_t product_hi = 0;
    uint32_t product_lo = 0;
    uint32_t shifted_hi = 0;
    uint32_t shifted_lo = multiplicand;

    while (multiplier != 0) {
        if (multiplier & 1u) {
            uint32_t old_lo = product_lo;
            product_lo += shifted_lo;
            product_hi += shifted_hi + (product_lo < old_lo);
        }
        shifted_hi = (shifted_hi << 1) | (shifted_lo >> 31);
        shifted_lo <<= 1;
        multiplier >>= 1;
    }

    if ((a < 0) != (b < 0)) {
        product_lo = 0u - product_lo;
        product_hi = ~product_hi + (product_lo == 0);
    }

    uint32_t old_lo = product_lo;
    product_lo += 1u << (Q - 1);
    product_hi += product_lo < old_lo;

    return (int32_t) ((product_lo >> Q) | (product_hi << (32 - Q)));
}
