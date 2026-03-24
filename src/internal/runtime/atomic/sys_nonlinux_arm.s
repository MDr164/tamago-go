// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !linux

#include "textflag.h"

// func Cas(ptr *int32, old int32, new int32) bool
// On ARMv6+ we use LDREX/STREX (via armcas).
// On ARMv5 (single-core, no LDREX) we disable interrupts to get
// atomicity, which is safe because non-linux GOARM<7 targets are
// defined as single-processor only (see comment below).
TEXT	·Cas(SB),NOSPLIT,$0
#ifdef GOARM_6
	JMP	·armcas(SB)
#else
	MOVW	ptr+0(FP), R1
	MOVW	old+4(FP), R2
	MOVW	new+8(FP), R3

	// Disable IRQ+FIQ, save old CPSR in R4.
	WORD	$0xe10f4000	// mrs r4, CPSR
	WORD	$0xe38400c0	// orr r0, r4, #0xc0
	WORD	$0xe121f000	// msr CPSR_c, r0

	MOVW	(R1), R0
	CMP	R0, R2
	BNE	casfailv5

	MOVW	R3, (R1)
	// Restore CPSR (re-enables interrupts if they were enabled).
	WORD	$0xe121f004	// msr CPSR_c, r4
	MOVW	$1, R0
	MOVB	R0, ret+12(FP)
	RET
casfailv5:
	WORD	$0xe121f004	// msr CPSR_c, r4
	MOVW	$0, R0
	MOVB	R0, ret+12(FP)
	RET
#endif

// Non-linux OSes support only single processor machines before ARMv7.
// So we don't need memory barriers if goarm < 7. And we fail loud at
// startup (runtime.checkgoarm) if it is a multi-processor but goarm < 7.

TEXT	·Load(SB),NOSPLIT|NOFRAME,$0-8
	MOVW	addr+0(FP), R0
	MOVW	(R0), R1

	MOVB	runtime·goarm(SB), R11
	CMP	$7, R11
	BLT	2(PC)
	DMB	MB_ISH

	MOVW	R1, ret+4(FP)
	RET

TEXT	·Store(SB),NOSPLIT,$0-8
	MOVW	addr+0(FP), R1
	MOVW	v+4(FP), R2

	MOVB	runtime·goarm(SB), R8
	CMP	$7, R8
	BLT	2(PC)
	DMB	MB_ISH

	MOVW	R2, (R1)

	CMP	$7, R8
	BLT	2(PC)
	DMB	MB_ISH
	RET

TEXT	·Load8(SB),NOSPLIT|NOFRAME,$0-5
	MOVW	addr+0(FP), R0
	MOVB	(R0), R1

	MOVB	runtime·goarm(SB), R11
	CMP	$7, R11
	BLT	2(PC)
	DMB	MB_ISH

	MOVB	R1, ret+4(FP)
	RET

TEXT	·Store8(SB),NOSPLIT,$0-5
	MOVW	addr+0(FP), R1
	MOVB	v+4(FP), R2

	MOVB	runtime·goarm(SB), R8
	CMP	$7, R8
	BLT	2(PC)
	DMB	MB_ISH

	MOVB	R2, (R1)

	CMP	$7, R8
	BLT	2(PC)
	DMB	MB_ISH
	RET

