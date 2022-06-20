//go:build !purego

#include "textflag.h"

// func hash64(seed, value uint64) uint64
TEXT ·hash64(SB), NOSPLIT, $0-24
    PXOR X0, X0
    PINSRQ $1, value+8(FP), X0
    AESENC runtime·aeskeysched+0(SB), X0
    MOVQ X0, AX
    MOVQ AX, ret+16(FP)
    RET

// func probe64(table []uint64, len, cap int, keys []uint64, values []int32) int
TEXT ·probe64(SB), NOSPLIT, $0-96
    MOVQ table_base+0(FP), AX
    MOVQ len+24(FP), BX
    MOVQ cap+32(FP), CX
    MOVQ keys_base+40(FP), DX
    MOVQ keys_len+48(FP), DI
    MOVQ values_base+64(FP), R15

    MOVQ CX, R8
    SHRQ $5, R8 // offset = cap / 64

    MOVQ CX, R9
    DECQ R9 // modulo = cap - 1

    XORQ SI, SI
    JMP test
loop:
    MOVQ (DX)(SI*8), CX // key

    PXOR X0, X0
    MOVQ CX, X0
    PINSRQ $1, CX, X0
    AESENC runtime·aeskeysched+0(SB), X0
    MOVQ X0, R10

probe:
    MOVQ R10, R11
    ANDQ R9, R11 // position = hash & modulo

    MOVQ R11, R12
    MOVQ R11, R13
    SHRQ $5, R12       // index = position / 64
    ANDQ $0b11111, R13 // shift = position % 64

    SHLQ $1, R11 // position *= 2
    ADDQ R8, R11 // position += offset

    MOVQ (AX)(R12*8), R14
    BTSQ R13, R14
    JNC insert // table[index] & 1<<shift == 0 ?

    CMPQ (AX)(R11*8), CX
    JNE nextprobe // table[2*position+offset] != keys[i] ?
    MOVL 8(AX)(R11*8), R11
    MOVL R11, (R15)(SI*4)
next:
    INCQ SI
test:
    CMPQ SI, DI
    JNE loop
    MOVQ BX, ret+88(FP)
    RET
insert:
    MOVQ R14, (AX)(R12*8)
    MOVQ CX, (AX)(R11*8)
    MOVQ BX, 8(AX)(R11*8)
    MOVL BX, (R15)(SI*4)
    INCQ BX // len++
    JMP next
nextprobe:
    INCQ R10
    JMP probe
