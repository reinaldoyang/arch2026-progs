#include "bf16.h"

enum {
    BF16_SIGN = 0x8000u,
    BF16_EXP = 0x7F80u,
    BF16_FRAC = 0x007Fu,
    BF16_INF = 0x7F80u,
    BF16_NAN = 0x7FC0u,
};

static uint32_t mul_u16(uint32_t a, uint32_t b)
{
    uint32_t product = 0;

    while (b != 0) {
        if (b & 1u)
            product += a;
        a <<= 1;
        b >>= 1;
    }
    return product;
}

uint16_t bf16_from_f32(uint32_t f32bits)
{
    if (((f32bits >> 23) & 0xFFu) == 0xFFu)
        return (uint16_t) (f32bits >> 16);

    f32bits += 0x7FFFu + ((f32bits >> 16) & 1u);
    return (uint16_t) (f32bits >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t sign = (a ^ b) & BF16_SIGN;
    int exp_a = (a >> 7) & 0xFFu;
    int exp_b = (b >> 7) & 0xFFu;
    uint32_t sig_a = a & BF16_FRAC;
    uint32_t sig_b = b & BF16_FRAC;

    if (exp_a == 0xFF) {
        if (sig_a != 0)
            return a;
        if ((b & ~BF16_SIGN) == 0)
            return BF16_NAN;
        return (uint16_t) (sign | BF16_INF);
    }
    if (exp_b == 0xFF) {
        if (sig_b != 0)
            return b;
        if ((a & ~BF16_SIGN) == 0)
            return BF16_NAN;
        return (uint16_t) (sign | BF16_INF);
    }
    if ((a & ~BF16_SIGN) == 0 || (b & ~BF16_SIGN) == 0)
        return (uint16_t) sign;

    if (exp_a == 0) {
        exp_a = 1;
        while ((sig_a & 0x80u) == 0) {
            sig_a <<= 1;
            exp_a--;
        }
    } else {
        sig_a |= 0x80u;
    }

    if (exp_b == 0) {
        exp_b = 1;
        while ((sig_b & 0x80u) == 0) {
            sig_b <<= 1;
            exp_b--;
        }
    } else {
        sig_b |= 0x80u;
    }

    uint32_t product = mul_u16(sig_a, sig_b);
    int exponent = exp_a + exp_b - 127;
    uint32_t significand = product >> 7;

    if (significand & 0x100u) {
        significand >>= 1;
        exponent++;
    }

    if (exponent >= 0xFF)
        return (uint16_t) (sign | BF16_INF);
    if (exponent <= 0) {
        if (exponent < -6)
            return (uint16_t) sign;
        uint32_t fraction = significand & BF16_FRAC;
        fraction >>= 1 - exponent;
        return (uint16_t) (sign | fraction);
    }

    return (uint16_t) (sign | ((uint32_t) exponent << 7) |
                       (significand & BF16_FRAC));
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t exponent = (a >> 7) & 0xFFu;
    uint32_t fraction = a & BF16_FRAC;

    if (exponent == 0xFFu) {
        if (fraction != 0)
            return a;
        return (a & BF16_SIGN) ? BF16_NAN : a;
    }
    if (a & BF16_SIGN)
        return (a & ~BF16_SIGN) == 0 ? 0 : BF16_NAN;
    if (exponent == 0)
        return 0;

    uint32_t significand = 0x80u | fraction;
    int result_exp;

    if ((exponent & 1u) == 0) {
        significand <<= 1;
        result_exp = (int) (exponent >> 1) + 63;
    } else {
        result_exp = (int) (exponent >> 1) + 64;
    }

    uint32_t low = 90;
    uint32_t high = 256;
    uint32_t root = 90;
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        if ((mul_u16(mid, mid) >> 7) <= significand) {
            root = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    if (root >= 256) {
        root >>= 1;
        result_exp++;
    } else if (root < 128) {
        root <<= 1;
        result_exp--;
    }

    if (result_exp >= 0xFF)
        return BF16_INF;
    if (result_exp <= 0)
        return 0;
    return (uint16_t) (((uint32_t) result_exp << 7) | (root & BF16_FRAC));
}
