.387
.386p
		PUBLIC	sf_unload_
		PUBLIC	sf_load_
		EXTRN	GLOBALALLOC:BYTE
		EXTRN	GLOBALLOCK:BYTE
		EXTRN	GLOBALFREE:BYTE
		EXTRN	GLOBALUNLOCK:BYTE
		EXTRN	__PIA:BYTE
		EXTRN	GETSELECTORBASE:BYTE
		EXTRN	HMEMCPY:BYTE
		EXTRN	_fmemset_:BYTE
		EXTRN	`IF@DPOW`:BYTE
		EXTRN	__I4M:BYTE
		EXTRN	__U4M:BYTE
		EXTRN	__PTC:BYTE
		EXTRN	__U4D:BYTE
		EXTRN	_HREAD:BYTE
		EXTRN	_LLSEEK:BYTE
		EXTRN	_LOPEN:BYTE
		EXTRN	_LCLOSE:BYTE
		EXTRN	__CHP:BYTE
		EXTRN	`IF@DLOG`:BYTE
		EXTRN	`IF@DTAN`:BYTE
		EXTRN	GETWINFLAGS:BYTE
		EXTRN	__DLLstart_:BYTE
DGROUP		GROUP	CONST,CONST2,_DATA
SFLOAD_TEXT		SEGMENT	PARA PUBLIC USE16 'CODE'
		ASSUME CS:SFLOAD_TEXT, DS:DGROUP, SS:DGROUP
sf_alloc_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,6
	mov		bx,dx
	or		bx,ax
	je		L$1
	cmp		dx,7fffH
	ja		L$1
	jne		L$2
	cmp		ax,0fff0H
	jbe		L$2
L$1:
	xor		ax,ax
	xor		dx,dx
	jmp		near ptr L$6
L$2:
	push		2042H
	add		ax,8
	mov		word ptr -0cH[bp],ax
	adc		dx,0
	mov		word ptr -0eH[bp],dx
	push		dx
	push		ax
	call		far ptr GLOBALALLOC
	mov		di,ax
	test		ax,ax
	jne		L$3
	xor		dx,dx
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
L$3:
	push		ax
	call		far ptr GLOBALLOCK
	mov		si,ax
	mov		word ptr -0aH[bp],dx
	mov		es,dx
	test		dx,dx
	jne		L$4
	test		ax,ax
	jne		L$4
	push		di
	call		far ptr GLOBALFREE
	xor		ax,ax
	xor		dx,dx
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
L$4:
	test		ax,ax
	je		L$5
	push		di
	call		far ptr GLOBALUNLOCK
	push		di
	call		far ptr GLOBALFREE
	xor		ax,ax
	xor		dx,dx
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
L$5:
	mov		ax,word ptr -0cH[bp]
	mov		word ptr es:[si],ax
	mov		ax,word ptr -0eH[bp]
	mov		word ptr es:2[si],ax
	mov		ax,si
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],di
	mov		ax,si
	mov		dx,word ptr -0aH[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
L$6:
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
sf_linear_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	sub		sp,2
	mov		si,ax
	push		dx
	call		far ptr GETSELECTORBASE
	mov		word ptr -8[bp],0
	add		ax,si
	adc		dx,word ptr -8[bp]
	lea		sp,-6[bp]
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
	cld
sf_pin_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,4
	mov		bx,0fff8H
	mov		cx,0ffffH
	call		far ptr __PIA
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		es,dx
	mov		si,ax
	mov		si,word ptr es:[si]
	mov		di,ax
	mov		di,word ptr es:2[di]
	call		near ptr sf_linear_
	mov		bx,ax
	mov		cx,dx
	mov		ax,600H
	xchg		bx,cx
	xchg		si,di
	int		31H
	xchg		si,di
	xchg		bx,cx
	sbb		ax,ax
	inc		ax
	mov		si,ax
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,6
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],si
	test		si,si
	setne		al
	xor		ah,ah
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
sf_free_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,4
	mov		di,ax
	mov		si,dx
	test		dx,dx
	jne		L$7
	test		ax,ax
	je		L$9
L$7:
	mov		bx,0fff8H
	mov		cx,0ffffH
	call		far ptr __PIA
	mov		word ptr -0aH[bp],ax
	mov		es,dx
	mov		ax,di
	mov		dx,si
	mov		bx,0fffcH
	mov		cx,0ffffH
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:[bx]
	mov		word ptr -0cH[bp],ax
	mov		ax,di
	mov		dx,si
	mov		bx,0fffeH
	mov		cx,0ffffH
	call		far ptr __PIA
	mov		si,ax
	mov		fs,dx
	cmp		word ptr fs:[si],0
	je		L$8
	mov		si,word ptr -0aH[bp]
	mov		si,word ptr es:[si]
	mov		di,word ptr -0aH[bp]
	mov		di,word ptr es:2[di]
	mov		ax,word ptr -0aH[bp]
	mov		dx,es
	call		near ptr sf_linear_
	mov		bx,ax
	mov		cx,dx
	mov		ax,601H
	xchg		bx,cx
	xchg		si,di
	int		31H
	xchg		si,di
	xchg		bx,cx
	sbb		ax,ax
	inc		ax
L$8:
	push		word ptr -0cH[bp]
	call		far ptr GLOBALUNLOCK
	push		word ptr -0cH[bp]
	call		far ptr GLOBALFREE
L$9:
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
	mov		ax,ax
sf_memcpy_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	mov		di,ax
	mov		si,dx
	mov		ax,word ptr 6[bp]
	or		ax,word ptr 4[bp]
	je		L$10
	push		dx
	push		di
	push		cx
	push		bx
	push		dword ptr 4[bp]
	call		far ptr HMEMCPY
L$10:
	mov		ax,di
	mov		dx,si
	pop		di
	pop		si
	pop		bp
	ret		4
sf_memset_:
	push		bp
	mov		bp,sp
	push		cx
	push		si
	push		di
	sub		sp,8
	mov		word ptr -0eH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		word ptr -0aH[bp],bx
	mov		si,ax
	mov		word ptr -8[bp],dx
L$11:
	mov		ax,word ptr 6[bp]
	or		ax,word ptr 4[bp]
	je		L$16
	xor		bx,bx
	xor		dx,dx
	sub		dx,si
	mov		ax,1
	sbb		ax,bx
	mov		bx,ax
	cmp		word ptr 6[bp],0
	jne		L$12
	cmp		word ptr 4[bp],7f00H
	jbe		L$13
L$12:
	mov		ax,7f00H
	jmp		L$14
L$13:
	mov		ax,word ptr 4[bp]
L$14:
	mov		di,ax
	test		bx,bx
	jne		L$15
	cmp		dx,ax
	jae		L$15
	mov		di,dx
L$15:
	mov		cx,di
	mov		bx,word ptr -0aH[bp]
	mov		ax,si
	mov		dx,word ptr -8[bp]
	call		far ptr _fmemset_
	mov		ax,si
	mov		dx,word ptr -8[bp]
	mov		bx,di
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		word ptr -8[bp],dx
	xor		ax,ax
	sub		word ptr 4[bp],di
	sbb		word ptr 6[bp],ax
	jmp		L$11
L$16:
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret		4
	mov		ax,ax
	cld
tsf_hydra_read_phdr_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,16H
	mov		word ptr -0eH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0aH[bp],ax
	mov		word ptr -8[bp],dx
	pushd		14H
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0eH[bp]
	mov		cx,word ptr -0cH[bp]
	les		di,dword ptr -0aH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$17
	cmp		ax,14H
	je		L$18
L$17:
	xor		ax,ax
	jmp		near ptr L$31
L$18:
	mov		word ptr -10H[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -18H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -18H[bp]
	mov		di,word ptr -10H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$19
	cmp		ax,2
	je		L$20
L$19:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$20:
	les		di,dword ptr -0aH[bp]
	pushd		2
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,16H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -1aH[bp],bx
	mov		bx,word ptr fs:2[si]
	mov		word ptr -18H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -1aH[bp]
	mov		dx,word ptr -18H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$21
	cmp		ax,2
	je		L$22
L$21:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$22:
	mov		word ptr -12H[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -18H[bp],bx
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -18H[bp]
	mov		dx,di
	mov		di,word ptr -12H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$23
	cmp		ax,2
	je		L$24
L$23:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$24:
	mov		bx,word ptr -0aH[bp]
	mov		word ptr -16H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		4
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,1aH
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -18H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -18H[bp]
	mov		di,word ptr -16H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$25
	cmp		ax,4
	je		L$26
L$25:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$26:
	mov		bx,word ptr -0aH[bp]
	mov		word ptr -14H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		4
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -18H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -18H[bp]
	mov		di,word ptr -14H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$27
	cmp		ax,4
	je		L$28
L$27:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$28:
	les		di,dword ptr -0aH[bp]
	pushd		4
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,22H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -18H[bp],bx
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -18H[bp]
	mov		dx,si
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$29
	cmp		ax,4
	je		L$30
L$29:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$30:
	mov		ax,1
L$31:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
tsf_hydra_read_pbag_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		word ptr -8[bp],dx
	pushd		2
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0aH[bp]
	mov		cx,word ptr -0cH[bp]
	mov		es,word ptr -8[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$32
	cmp		ax,2
	je		L$33
L$32:
	xor		ax,ax
	jmp		L$36
L$33:
	mov		word ptr -0eH[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,si
	mov		si,word ptr -0eH[bp]
	call		dword ptr es:[si]
	test		dx,dx
	jne		L$34
	cmp		ax,2
	je		L$35
L$34:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$35:
	mov		ax,1
L$36:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	mov		ax,ax
	cld
tsf_hydra_read_pmod_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,12H
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0eH[bp],ax
	mov		word ptr -8[bp],dx
	pushd		2
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0cH[bp]
	les		cx,dword ptr -0aH[bp]
	mov		di,word ptr -0eH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$37
	cmp		ax,2
	je		L$38
L$37:
	xor		ax,ax
	jmp		near ptr L$47
L$38:
	mov		word ptr -12H[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -16H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -16H[bp]
	mov		di,word ptr -12H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$39
	cmp		ax,2
	je		L$40
L$39:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$40:
	mov		bx,word ptr -0eH[bp]
	mov		word ptr -14H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -16H[bp],bx
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -16H[bp]
	mov		dx,di
	mov		di,word ptr -14H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$41
	cmp		ax,2
	je		L$42
L$41:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$42:
	mov		bx,word ptr -0eH[bp]
	mov		word ptr -10H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,6
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -16H[bp],bx
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -16H[bp]
	mov		dx,di
	mov		di,word ptr -10H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$43
	cmp		ax,2
	je		L$44
L$43:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$44:
	mov		bx,word ptr -0eH[bp]
	mov		word ptr -16H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,si
	mov		si,word ptr -16H[bp]
	call		dword ptr es:[si]
	test		dx,dx
	jne		L$45
	cmp		ax,2
	je		L$46
L$45:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$46:
	mov		ax,1
L$47:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	mov		ax,ax
	cld
tsf_hydra_read_pgen_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		word ptr -8[bp],dx
	pushd		2
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0aH[bp]
	mov		cx,word ptr -0cH[bp]
	mov		es,word ptr -8[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$48
	cmp		ax,2
	je		L$49
L$48:
	xor		ax,ax
	jmp		L$52
L$49:
	mov		word ptr -0eH[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,si
	mov		si,word ptr -0eH[bp]
	call		dword ptr es:[si]
	test		dx,dx
	jne		L$50
	cmp		ax,2
	je		L$51
L$50:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$51:
	mov		ax,1
L$52:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	mov		ax,ax
	cld
tsf_hydra_read_inst_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		word ptr -8[bp],dx
	pushd		14H
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0aH[bp]
	mov		cx,word ptr -0cH[bp]
	mov		es,word ptr -8[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$53
	cmp		ax,14H
	je		L$54
L$53:
	xor		ax,ax
	jmp		L$57
L$54:
	mov		word ptr -0eH[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,si
	mov		si,word ptr -0eH[bp]
	call		dword ptr es:[si]
	test		dx,dx
	jne		L$55
	cmp		ax,2
	je		L$56
L$55:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$56:
	mov		ax,1
L$57:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	mov		ax,ax
	cld
tsf_hydra_read_ibag_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		word ptr -8[bp],dx
	pushd		2
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0aH[bp]
	mov		cx,word ptr -0cH[bp]
	mov		es,word ptr -8[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$58
	cmp		ax,2
	je		L$59
L$58:
	xor		ax,ax
	jmp		L$62
L$59:
	mov		word ptr -0eH[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,si
	mov		si,word ptr -0eH[bp]
	call		dword ptr es:[si]
	test		dx,dx
	jne		L$60
	cmp		ax,2
	je		L$61
L$60:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$61:
	mov		ax,1
L$62:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	mov		ax,ax
	cld
tsf_hydra_read_imod_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,12H
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0eH[bp],ax
	mov		word ptr -8[bp],dx
	pushd		2
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0cH[bp]
	les		cx,dword ptr -0aH[bp]
	mov		di,word ptr -0eH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$63
	cmp		ax,2
	je		L$64
L$63:
	xor		ax,ax
	jmp		near ptr L$73
L$64:
	mov		word ptr -12H[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -16H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -16H[bp]
	mov		di,word ptr -12H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$65
	cmp		ax,2
	je		L$66
L$65:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$66:
	mov		bx,word ptr -0eH[bp]
	mov		word ptr -14H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -16H[bp],bx
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -16H[bp]
	mov		dx,di
	mov		di,word ptr -14H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$67
	cmp		ax,2
	je		L$68
L$67:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$68:
	mov		bx,word ptr -0eH[bp]
	mov		word ptr -10H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,6
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -16H[bp],bx
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -16H[bp]
	mov		dx,di
	mov		di,word ptr -10H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$69
	cmp		ax,2
	je		L$70
L$69:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$70:
	mov		bx,word ptr -0eH[bp]
	mov		word ptr -16H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,si
	mov		si,word ptr -16H[bp]
	call		dword ptr es:[si]
	test		dx,dx
	jne		L$71
	cmp		ax,2
	je		L$72
L$71:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$72:
	mov		ax,1
L$73:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	mov		ax,ax
	cld
tsf_hydra_read_igen_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		word ptr -8[bp],dx
	pushd		2
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0aH[bp]
	mov		cx,word ptr -0cH[bp]
	mov		es,word ptr -8[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$74
	cmp		ax,2
	je		L$75
L$74:
	xor		ax,ax
	jmp		L$78
L$75:
	mov		word ptr -0eH[bp],di
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,si
	mov		si,word ptr -0eH[bp]
	call		dword ptr es:[si]
	test		dx,dx
	jne		L$76
	cmp		ax,2
	je		L$77
L$76:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$77:
	mov		ax,1
L$78:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	mov		ax,ax
	cld
tsf_hydra_read_shdr_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,1cH
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0eH[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0cH[bp],ax
	mov		word ptr -8[bp],dx
	pushd		14H
	mov		es,word ptr -6[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	mov		bx,word ptr -0aH[bp]
	mov		cx,word ptr -0eH[bp]
	mov		es,word ptr -8[bp]
	mov		di,word ptr -0cH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$79
	cmp		ax,14H
	je		L$80
L$79:
	xor		ax,ax
	jmp		near ptr L$99
L$80:
	mov		word ptr -16H[bp],di
	mov		es,word ptr -8[bp]
	pushd		4
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		word ptr -20H[bp],di
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -20H[bp]
	mov		dx,di
	mov		di,word ptr -16H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$81
	cmp		ax,4
	je		L$82
L$81:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$82:
	mov		bx,word ptr -0cH[bp]
	mov		word ptr -14H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		4
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -20H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -20H[bp]
	mov		di,word ptr -14H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$83
	cmp		ax,4
	je		L$84
L$83:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$84:
	mov		bx,word ptr -0cH[bp]
	mov		word ptr -1cH[bp],bx
	mov		es,word ptr -8[bp]
	pushd		4
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -20H[bp],bx
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -20H[bp]
	mov		dx,di
	mov		di,word ptr -1cH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$85
	cmp		ax,4
	je		L$86
L$85:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$86:
	mov		bx,word ptr -0cH[bp]
	mov		word ptr -10H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		4
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,20H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -20H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -20H[bp]
	mov		di,word ptr -10H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$87
	cmp		ax,4
	je		L$88
L$87:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$88:
	mov		bx,word ptr -0cH[bp]
	mov		word ptr -12H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		4
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,24H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -20H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -20H[bp]
	mov		di,word ptr -12H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$89
	cmp		ax,4
	je		L$90
L$89:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$90:
	mov		bx,word ptr -0cH[bp]
	mov		word ptr -1eH[bp],bx
	mov		es,word ptr -8[bp]
	pushd		1
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,28H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -20H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -20H[bp]
	mov		di,word ptr -1eH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$91
	cmp		ax,1
	je		L$92
L$91:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$92:
	mov		bx,word ptr -0cH[bp]
	mov		word ptr -1aH[bp],bx
	mov		es,word ptr -8[bp]
	pushd		1
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,29H
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		di,word ptr fs:[si]
	mov		bx,word ptr fs:2[si]
	mov		word ptr -20H[bp],bx
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -20H[bp]
	mov		di,word ptr -1aH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$93
	cmp		ax,1
	je		L$94
L$93:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$94:
	mov		bx,word ptr -0cH[bp]
	mov		word ptr -18H[bp],bx
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,2aH
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -20H[bp],bx
	mov		di,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -20H[bp]
	mov		dx,di
	mov		di,word ptr -18H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$95
	cmp		ax,2
	je		L$96
L$95:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$96:
	mov		di,word ptr -0cH[bp]
	mov		es,word ptr -8[bp]
	pushd		2
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,2cH
	xor		cx,cx
	call		far ptr __PIA
	mov		fs,word ptr -6[bp]
	mov		bx,word ptr fs:[si]
	mov		word ptr -20H[bp],bx
	mov		si,word ptr fs:2[si]
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -20H[bp]
	mov		dx,si
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$97
	cmp		ax,2
	je		L$98
L$97:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$98:
	mov		ax,1
L$99:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
tsf_timecents2Secsf_:
	push		ax
	push		bp
	mov		bp,sp
	fld		dword ptr 6[bp]
	fdiv		dword ptr DGROUP:L$433
	fld		qword ptr DGROUP:L$434
	call		far ptr `IF@DPOW`
	pop		bp
	pop		ax
	ret		4
	mov		ax,ax
	cld
tsf_decibelsToGain_:
	push		ax
	push		bp
	mov		bp,sp
	sub		sp,4
	fld		dword ptr 6[bp]
	fcomp		dword ptr DGROUP:L$435
	fnstsw		ax
	sahf
	jbe		L$100
	fld		dword ptr 6[bp]
	fmul		dword ptr DGROUP:L$436
	fld		qword ptr DGROUP:L$437
	call		far ptr `IF@DPOW`
	fstp		dword ptr -4[bp]
	jmp		L$101
L$100:
	xor		ax,ax
	mov		word ptr -4[bp],ax
	mov		word ptr -2[bp],ax
L$101:
	fld		dword ptr -4[bp]
	leave
	pop		ax
	ret		4
tsf_riffchunk_read_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,10H
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		si,bx
	mov		word ptr -14H[bp],cx
	test		dx,dx
	jne		L$102
	test		ax,ax
	je		L$103
L$102:
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	cmp		word ptr es:2[di],0
	jne		L$103
	cmp		word ptr es:[di],8
	jae		L$103
	xor		al,al
	jmp		near ptr L$124
L$103:
	mov		ax,word ptr 4[bp]
	mov		dx,word ptr 6[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		word ptr -12H[bp],dx
	pushd		4
	les		bx,dword ptr 4[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	les		cx,dword ptr -14H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$104
	cmp		ax,4
	jne		L$104
	mov		es,word ptr -14H[bp]
	mov		al,byte ptr es:[si]
	cmp		al,20H
	jbe		L$104
	cmp		al,7aH
	jb		L$105
L$104:
	xor		al,al
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$105:
	mov		es,word ptr -12H[bp]
	pushd		4
	mov		ax,si
	mov		dx,word ptr -14H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -10H[bp],ax
	mov		word ptr -0eH[bp],dx
	lfs		bx,dword ptr 4[bp]
	mov		ax,word ptr fs:[bx]
	mov		dx,word ptr fs:2[bx]
	mov		bx,word ptr -10H[bp]
	mov		cx,word ptr -0eH[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$106
	cmp		ax,4
	je		L$107
L$106:
	xor		al,al
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$107:
	cmp		word ptr -0aH[bp],0
	jne		L$108
	cmp		word ptr -0cH[bp],0
	je		L$110
L$108:
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		dx,word ptr es:[di]
	add		dx,0fff8H
	mov		ax,word ptr es:2[di]
	adc		ax,0ffffH
	les		bx,dword ptr -10H[bp]
	cmp		ax,word ptr es:2[bx]
	jb		L$109
	jne		L$110
	cmp		dx,word ptr es:[bx]
	jae		L$110
L$109:
	xor		al,al
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$110:
	cmp		word ptr -0aH[bp],0
	jne		L$111
	cmp		word ptr -0cH[bp],0
	je		L$112
L$111:
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		ax,si
	mov		dx,word ptr -14H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:[bx]
	add		ax,8
	mov		dx,word ptr fs:2[bx]
	adc		dx,0
	sub		word ptr es:[di],ax
	sbb		word ptr es:2[di],dx
L$112:
	mov		es,word ptr -14H[bp]
	mov		al,byte ptr es:[si]
	cmp		al,byte ptr DGROUP:L$438
	jne		L$113
	mov		ax,si
	mov		dx,es
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		ax,offset DGROUP:L$438
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		al,byte ptr es:[di]
	cmp		al,byte ptr fs:[bx]
	jne		L$113
	mov		ax,si
	mov		dx,word ptr -14H[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		ax,offset DGROUP:L$438
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		al,byte ptr es:[di]
	cmp		al,byte ptr fs:[bx]
	jne		L$113
	mov		ax,si
	mov		dx,word ptr -14H[bp]
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		fs,dx
	mov		ax,offset DGROUP:L$438
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr fs:[di]
	cmp		al,byte ptr es:[bx]
	jne		L$113
	mov		al,1
	jmp		L$114
L$113:
	xor		al,al
L$114:
	mov		byte ptr -6[bp],al
	mov		es,word ptr -14H[bp]
	mov		al,byte ptr es:[si]
	cmp		al,byte ptr DGROUP:L$439
	jne		L$115
	mov		ax,si
	mov		dx,es
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		ax,offset DGROUP:L$439
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		al,byte ptr es:[di]
	cmp		al,byte ptr fs:[bx]
	jne		L$115
	mov		ax,si
	mov		dx,word ptr -14H[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		ax,offset DGROUP:L$439
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		al,byte ptr es:[di]
	cmp		al,byte ptr fs:[bx]
	jne		L$115
	mov		ax,si
	mov		dx,word ptr -14H[bp]
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		fs,dx
	mov		ax,offset DGROUP:L$439
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr fs:[di]
	cmp		al,byte ptr es:[bx]
	jne		L$115
	mov		al,1
	jmp		L$116
L$115:
	xor		al,al
L$116:
	mov		byte ptr -8[bp],al
	cmp		byte ptr -6[bp],0
	je		L$117
	cmp		word ptr -0aH[bp],0
	jne		L$119
	cmp		word ptr -0cH[bp],0
	jne		L$119
L$117:
	cmp		byte ptr -6[bp],0
	jne		L$118
	cmp		byte ptr -8[bp],0
	je		L$120
L$118:
	mov		ax,si
	mov		dx,word ptr -14H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	cmp		word ptr es:2[di],0
	jne		L$120
	cmp		word ptr es:[di],4
	jae		L$120
L$119:
	xor		al,al
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$120:
	cmp		byte ptr -6[bp],0
	jne		L$121
	cmp		byte ptr -8[bp],0
	jne		L$121
	mov		al,1
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$121:
	mov		ax,word ptr 4[bp]
	mov		dx,word ptr 6[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	pushd		4
	lfs		bx,dword ptr 4[bp]
	mov		ax,word ptr fs:[bx]
	mov		dx,word ptr fs:2[bx]
	mov		bx,si
	mov		cx,word ptr -14H[bp]
	call		dword ptr es:[di]
	test		dx,dx
	jne		L$122
	cmp		ax,4
	jne		L$122
	mov		es,word ptr -14H[bp]
	mov		al,byte ptr es:[si]
	cmp		al,20H
	jbe		L$122
	cmp		al,7aH
	jb		L$123
L$122:
	xor		al,al
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$123:
	mov		ax,si
	mov		dx,es
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		al,1
	add		word ptr es:[si],0fffcH
	adc		word ptr es:2[si],0ffffH
L$124:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
	cld
tsf_region_clear_:
	push		bp
	mov		bp,sp
	push		cx
	push		si
	push		di
	sub		sp,6
	mov		di,ax
	mov		si,dx
	mov		byte ptr -0aH[bp],bl
	push		0
	push		8aH
	xor		bx,bx
	call		near ptr sf_memset_
	mov		ax,di
	mov		dx,si
	mov		bx,9
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		byte ptr es:[bx],7fH
	mov		bl,byte ptr es:[bx]
	mov		byte ptr -8[bp],bl
	mov		ax,di
	mov		dx,si
	mov		bx,7
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -8[bp]
	mov		byte ptr es:[bx],al
	mov		ax,di
	mov		dx,si
	mov		bx,20H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0cH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		word ptr es:[bx],3cH
	cmp		byte ptr -0aH[bp],0
	jne		L$125
	mov		ax,di
	mov		dx,si
	mov		bx,22H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		word ptr fs:[bx],64H
	mov		bx,word ptr -0cH[bp]
	mov		word ptr es:[bx],0ffffH
	mov		ax,di
	mov		dx,si
	mov		bx,42H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dword ptr es:[bx],0c63b8000H
	fld		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,3aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fst		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,36H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fst		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,32H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fst		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,2eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fstp		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,62H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dword ptr es:[bx],0c63b8000H
	fld		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,5aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fst		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,56H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fst		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,52H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fst		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,4eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fstp		dword ptr es:[bx]
	mov		ax,di
	mov		dx,si
	mov		bx,70H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],34bcH
	mov		ax,di
	mov		dx,si
	mov		bx,7aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dword ptr es:[bx],0c63b8000H
	mov		ax,di
	mov		dx,si
	mov		bx,82H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dword ptr es:[bx],0c63b8000H
L$125:
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$126:
    DW	offset L$128
    DW	offset L$139
    DW	offset L$130
    DW	offset L$131
    DW	offset L$132
    DW	offset L$133
    DW	offset L$134
    DW	offset L$137
    DW	offset L$138
	mov		ax,ax
tsf_region_operator_:
	push		cx
	push		si
	push		di
	push		bp
	mov		bp,sp
	sub		sp,18H
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		word ptr -4[bp],bx
	mov		si,word ptr 0aH[bp]
	cmp		word ptr 0cH[bp],0
	jne		L$127
	test		si,si
	je		L$140
L$127:
	cmp		bx,3bH
	jae		L$129
	mov		ax,bx
	cwd
	mov		bx,ax
	mov		cx,dx
	add		bx,ax
	adc		cx,dx
	add		bx,bx
	adc		cx,cx
	mov		ax,offset DGROUP:L$486
	mov		dx,ds
	call		far ptr __PIA
	mov		di,ax
	mov		fs,dx
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		bx,word ptr es:[bx]
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr fs:[di]
	and		al,0fH
	dec		al
	cmp		al,8
	ja		L$129
	xor		ah,ah
	mov		di,ax
	add		di,ax
	jmp		word ptr cs:L$126[di]
L$128:
	mov		fs,word ptr 0cH[bp]
	fild		word ptr fs:[si]
	fstp		dword ptr es:[bx]
L$129:
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$130:
	mov		fs,word ptr 0cH[bp]
	mov		ax,word ptr fs:[si]
	cwd
	add		word ptr es:[bx],ax
	adc		word ptr es:2[bx],dx
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$131:
	mov		fs,word ptr 0cH[bp]
	mov		ax,word ptr fs:[si]
	cwd
	mov		cl,0fH
	shl		dx,cl
	rol		ax,cl
	xor		dx,ax
	and		ax,8000H
	xor		dx,ax
	add		word ptr es:[bx],ax
	adc		word ptr es:2[bx],dx
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$132:
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,6
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		fs,word ptr 0cH[bp]
	mov		al,byte ptr fs:[si]
	mov		byte ptr es:[bx],al
	mov		ax,si
	mov		dx,fs
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,7
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		al,byte ptr es:[si]
	mov		byte ptr fs:[bx],al
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$133:
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		fs,word ptr 0cH[bp]
	mov		al,byte ptr fs:[si]
	mov		byte ptr es:[bx],al
	mov		ax,si
	mov		dx,fs
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,9
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		al,byte ptr es:[si]
	mov		byte ptr fs:[bx],al
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$134:
	mov		es,word ptr 0cH[bp]
	mov		ax,word ptr es:[si]
	and		ax,3
	cmp		ax,3
	jne		L$135
	mov		ax,2
	jmp		L$136
L$135:
	cmp		ax,1
	sete		al
	xor		ah,ah
L$136:
	les		bx,dword ptr -0cH[bp]
	mov		word ptr es:[bx],ax
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$137:
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		fs,word ptr 0cH[bp]
	mov		ax,word ptr fs:[si]
	mov		word ptr es:[bx],ax
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$138:
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,20H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
L$139:
	mov		fs,word ptr 0cH[bp]
	mov		ax,word ptr fs:[si]
	mov		word ptr es:[bx],ax
	leave
	pop		di
	pop		si
	pop		cx
	ret		8
L$140:
	mov		word ptr -4[bp],0
	jmp		near ptr L$164
L$141:
	cmp		cl,80H
	je		L$143
	cmp		cl,70H
	je		L$142
	cmp		cl,60H
	jne		L$163
	mov		dword ptr -10H[bp],3f800000H
	mov		dword ptr -14H[bp],0c63b8000H
	mov		dword ptr -18H[bp],459c4000H
	jmp		near ptr L$148
L$142:
	mov		dword ptr -10H[bp],3f800000H
	mov		dword ptr -14H[bp],0c63b8000H
	mov		dword ptr -18H[bp],45fa0000H
	jmp		near ptr L$148
L$143:
	mov		dword ptr -10H[bp],3f800000H
	mov		dword ptr -14H[bp],0c4960000H
	mov		dword ptr -18H[bp],44960000H
	jmp		L$148
L$144:
	mov		dword ptr -10H[bp],3a83126fH
	mov		dword ptr -14H[bp],0bf000000H
	mov		dword ptr -18H[bp],3f000000H
	jmp		L$148
L$145:
	mov		dword ptr -10H[bp],3d23d70aH
	mov		dword ptr -14H[bp],0c2666666H
	mov		dword ptr -18H[bp],42666666H
	jmp		L$148
L$146:
	mov		dword ptr -10H[bp],3f800000H
	xor		ax,ax
	mov		word ptr -14H[bp],ax
	mov		word ptr -12H[bp],ax
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],447aH
	jmp		L$148
L$147:
	mov		dword ptr -10H[bp],3f800000H
	xor		ax,ax
	mov		word ptr -14H[bp],ax
	mov		word ptr -12H[bp],ax
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],44b4H
L$148:
	mov		es,dx
	fld		dword ptr es:[bx]
	fmul		dword ptr -10H[bp]
	fst		dword ptr es:[bx]
	fcomp		dword ptr -14H[bp]
	fnstsw		ax
	sahf
	jae		L$149
	mov		ax,word ptr -14H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:2[bx],ax
	jmp		near ptr L$163
L$149:
	fld		dword ptr es:[bx]
	fcomp		dword ptr -18H[bp]
	fnstsw		ax
	sahf
	jbe		L$163
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -16H[bp]
	mov		word ptr es:2[bx],ax
	jmp		near ptr L$163
L$150:
	mov		word ptr -8[bp],si
	mov		word ptr -6[bp],es
	mov		ax,word ptr es:[si]
	cwd
	mov		bx,ax
	mov		si,dx
	mov		ax,word ptr gs:[di]
	cwd
	mov		di,bx
	add		di,ax
	adc		si,dx
	mov		bx,word ptr -2[bp]
	mov		bl,byte ptr fs:[bx]
	and		bl,0f0H
	cmp		bl,30H
	jb		L$151
	jbe		L$153
	cmp		bl,50H
	je		L$155
	cmp		bl,40H
	je		L$154
	jmp		L$156
L$151:
	cmp		bl,20H
	je		L$152
	cmp		bl,10H
	jne		L$156
	mov		bx,0d120H
	mov		cx,2ee0H
	jmp		L$157
L$152:
	mov		bx,5dcH
	mov		cx,34bcH
	jmp		L$157
L$153:
	xor		bx,bx
	mov		cx,3c0H
	jmp		L$157
L$154:
	mov		bx,0fc40H
	mov		cx,3c0H
	jmp		L$157
L$155:
	mov		bx,0c180H
	mov		cx,1194H
	jmp		L$157
L$156:
	mov		bx,8000H
	mov		cx,7fffH
L$157:
	mov		ax,bx
	cwd
	cmp		si,dx
	jl		L$158
	jne		L$159
	cmp		di,ax
	jae		L$159
L$158:
	les		si,dword ptr -8[bp]
	mov		word ptr es:[si],bx
	jmp		L$163
L$159:
	mov		ax,cx
	cwd
	cmp		si,dx
	jg		L$160
	jne		L$161
	cmp		di,ax
	jbe		L$161
L$160:
	les		bx,dword ptr -8[bp]
	mov		word ptr es:[bx],cx
	jmp		L$163
L$161:
	les		bx,dword ptr -8[bp]
	mov		word ptr es:[bx],di
	jmp		L$163
L$162:
	mov		ax,word ptr gs:[di]
	mov		dx,word ptr gs:2[di]
	add		word ptr es:[si],ax
	adc		word ptr es:2[si],dx
L$163:
	inc		word ptr -4[bp]
	cmp		word ptr -4[bp],3bH
	je		L$129
L$164:
	mov		ax,word ptr -4[bp]
	cwd
	mov		bx,ax
	mov		cx,dx
	add		bx,ax
	adc		cx,dx
	add		bx,bx
	adc		cx,cx
	mov		ax,offset DGROUP:L$486
	mov		dx,ds
	call		far ptr __PIA
	mov		word ptr -2[bp],ax
	mov		fs,dx
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		di,word ptr es:[di]
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,di
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr 0eH[bp]
	mov		dx,word ptr 10H[bp]
	mov		bx,di
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		gs,dx
	mov		bx,word ptr -2[bp]
	mov		cl,byte ptr fs:[bx]
	and		cl,0fH
	cmp		cl,3
	je		L$162
	cmp		cl,2
	je		L$150
	cmp		cl,1
	jne		L$163
	mov		bx,si
	mov		dx,es
	fld		dword ptr gs:[di]
	fadd		dword ptr es:[si]
	fstp		dword ptr es:[si]
	mov		si,word ptr -2[bp]
	mov		cl,byte ptr fs:[si]
	and		cl,0f0H
	cmp		cl,90H
	jb		L$141
	jbe		L$144
	cmp		cl,0c0H
	je		L$147
	cmp		cl,0b0H
	je		L$146
	cmp		cl,0a0H
	je		L$145
	jmp		near ptr L$163
	mov		ax,ax
	cld
tsf_region_envtosecs_:
	push		bp
	mov		bp,sp
	push		cx
	push		si
	push		di
	sub		sp,16H
	mov		si,ax
	mov		di,dx
	mov		byte ptr -8[bp],bl
	mov		es,dx
	fld		dword ptr es:[si]
	fcomp		dword ptr DGROUP:L$440
	fnstsw		ax
	sahf
	jae		L$165
	xor		ax,ax
	mov		word ptr -14H[bp],ax
	mov		word ptr -12H[bp],ax
	jmp		L$166
L$165:
	push		dword ptr es:[si]
	call		near ptr tsf_timecents2Secsf_
	fstp		dword ptr -14H[bp]
L$166:
	mov		bx,word ptr -14H[bp]
	mov		es,di
	mov		word ptr es:[si],bx
	mov		bx,word ptr -12H[bp]
	mov		word ptr es:2[si],bx
	mov		ax,si
	mov		dx,di
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	fcomp		dword ptr DGROUP:L$440
	fnstsw		ax
	sahf
	jae		L$167
	xor		ax,ax
	mov		word ptr -1cH[bp],ax
	mov		word ptr -1aH[bp],ax
	jmp		L$168
L$167:
	push		dword ptr es:[bx]
	call		near ptr tsf_timecents2Secsf_
	fstp		dword ptr -1cH[bp]
L$168:
	mov		ax,si
	mov		dx,di
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -1cH[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -1aH[bp]
	mov		word ptr es:2[bx],ax
	mov		ax,si
	mov		dx,di
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	fcomp		dword ptr DGROUP:L$440
	fnstsw		ax
	sahf
	jae		L$169
	xor		ax,ax
	mov		word ptr -10H[bp],ax
	mov		word ptr -0eH[bp],ax
	jmp		L$170
L$169:
	push		dword ptr es:[bx]
	call		near ptr tsf_timecents2Secsf_
	fstp		dword ptr -10H[bp]
L$170:
	mov		ax,si
	mov		dx,di
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -10H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0eH[bp]
	mov		word ptr es:2[bx],ax
	mov		ax,si
	mov		dx,di
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	test		word ptr es:2[bx],7fffH
	jne		L$173
	cmp		word ptr es:[bx],0
	jne		L$173
	mov		ax,si
	mov		dx,di
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	fcomp		dword ptr DGROUP:L$440
	fnstsw		ax
	sahf
	jae		L$171
	xor		ax,ax
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],ax
	jmp		L$172
L$171:
	push		dword ptr es:[bx]
	call		near ptr tsf_timecents2Secsf_
	fstp		dword ptr -18H[bp]
L$172:
	mov		ax,si
	mov		dx,di
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -16H[bp]
	mov		word ptr es:2[bx],ax
L$173:
	mov		ax,si
	mov		dx,di
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	test		word ptr es:2[bx],7fffH
	jne		L$176
	cmp		word ptr es:[bx],0
	jne		L$176
	mov		ax,si
	mov		dx,di
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	fcomp		dword ptr DGROUP:L$440
	fnstsw		ax
	sahf
	jae		L$174
	xor		ax,ax
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],ax
	jmp		L$175
L$174:
	push		dword ptr es:[bx]
	call		near ptr tsf_timecents2Secsf_
	fstp		dword ptr -0cH[bp]
L$175:
	mov		ax,si
	mov		dx,di
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -0cH[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0aH[bp]
	mov		word ptr es:2[bx],ax
L$176:
	mov		ax,si
	mov		dx,di
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	fldz
	fcomp		dword ptr es:[si]
	fnstsw		ax
	sahf
	jbe		L$177
	mov		dword ptr es:[si],0
	jmp		L$180
L$177:
	cmp		byte ptr -8[bp],0
	je		L$178
	fld		dword ptr es:[si]
	fchs
	fdiv		dword ptr DGROUP:L$442
	sub		sp,4
	mov		bx,sp
	fstp		dword ptr ss:[bx]
	call		near ptr tsf_decibelsToGain_
	mov		es,dx
	jmp		L$179
L$178:
	fld		dword ptr es:[si]
	fdiv		dword ptr DGROUP:L$441
	fld1
	fsubrp		st(1),st
L$179:
	fstp		dword ptr es:[si]
L$180:
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
	cld
tsf_valid_hydra_:
	push		bx
	push		cx
	push		si
	push		di
	push		bp
	mov		bp,sp
	sub		sp,24H
	mov		si,ax
	mov		es,dx
	mov		bx,24H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:2[bx],0
	jne		L$181
	cmp		word ptr fs:[bx],2
	jb		L$184
L$181:
	cmp		word ptr fs:2[bx],0
	jne		L$184
	cmp		word ptr fs:[bx],7fffH
	ja		L$184
	mov		ax,si
	mov		dx,es
	mov		bx,34H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:2[bx],0
	jne		L$182
	cmp		word ptr fs:[bx],2
	jb		L$184
L$182:
	mov		ax,si
	mov		dx,es
	mov		bx,44H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:2[bx],0
	jne		L$183
	cmp		word ptr fs:[bx],2
	jb		L$184
L$183:
	mov		ax,si
	mov		dx,es
	mov		bx,28H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	or		ax,word ptr fs:[bx]
	je		L$184
	mov		ax,si
	mov		dx,es
	mov		bx,30H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	or		ax,word ptr fs:[bx]
	je		L$184
	mov		ax,si
	mov		dx,es
	mov		bx,38H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	or		ax,word ptr fs:[bx]
	je		L$184
	mov		ax,si
	mov		dx,es
	mov		bx,40H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	or		ax,word ptr fs:[bx]
	jne		L$185
L$184:
	xor		ax,ax
	jmp		near ptr L$218
L$185:
	mov		word ptr -2[bp],0
	xor		di,di
L$186:
	mov		ax,si
	mov		dx,es
	mov		bx,24H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	cmp		di,ax
	jb		L$187
	jne		L$191
	mov		ax,word ptr -2[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$191
L$187:
	mov		ax,word ptr -2[bp]
	mov		dx,di
	mov		bx,26H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr es:[si]
	mov		word ptr -12H[bp],ax
	mov		ax,word ptr es:2[si]
	mov		word ptr -1aH[bp],ax
	mov		ax,word ptr -12H[bp]
	mov		dx,word ptr -1aH[bp]
	call		far ptr __PIA
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6[bp],ax
	mov		gs,dx
	mov		bx,ax
	mov		ax,word ptr gs:[bx]
	mov		word ptr -20H[bp],ax
	mov		ax,si
	mov		dx,es
	mov		bx,28H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:2[bx],0
	jne		L$188
	mov		ax,word ptr -20H[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$189
L$188:
	mov		ax,word ptr -2[bp]
	or		ax,di
	je		L$190
	mov		ax,word ptr -2[bp]
	add		ax,0ffffH
	mov		dx,di
	adc		dx,0ffffH
	mov		bx,26H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -12H[bp]
	mov		dx,word ptr -1aH[bp]
	call		far ptr __PIA
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -6[bp]
	mov		ax,word ptr gs:[bx]
	mov		bx,cx
	cmp		ax,word ptr fs:[bx]
	jae		L$190
L$189:
	xor		ax,ax
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
L$190:
	add		word ptr -2[bp],1
	adc		di,0
	jmp		near ptr L$186
L$191:
	mov		word ptr -2[bp],0
	xor		di,di
L$192:
	mov		ax,si
	mov		dx,es
	mov		bx,28H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	cmp		di,ax
	jb		L$193
	jne		L$197
	mov		ax,word ptr -2[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$197
L$193:
	mov		ax,si
	mov		dx,es
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr -2[bp]
	mov		word ptr -24H[bp],ax
	mov		word ptr -22H[bp],di
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	mov		ax,word ptr fs:[bx]
	mov		word ptr -16H[bp],ax
	mov		ax,word ptr fs:2[bx]
	mov		word ptr -1cH[bp],ax
	mov		ax,word ptr -16H[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,word ptr -24H[bp]
	mov		cx,word ptr -22H[bp]
	call		far ptr __PIA
	mov		word ptr -0cH[bp],ax
	mov		gs,dx
	mov		bx,ax
	mov		ax,word ptr gs:[bx]
	mov		word ptr -20H[bp],ax
	mov		ax,si
	mov		dx,es
	mov		bx,30H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:2[bx],0
	jne		L$194
	mov		ax,word ptr -20H[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$195
L$194:
	mov		ax,word ptr -2[bp]
	or		ax,di
	je		L$196
	mov		dx,word ptr -2[bp]
	add		dx,0ffffH
	mov		ax,di
	adc		ax,0ffffH
	mov		word ptr -24H[bp],dx
	mov		word ptr -22H[bp],ax
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	mov		ax,word ptr -16H[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,word ptr -24H[bp]
	mov		cx,word ptr -22H[bp]
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -0cH[bp]
	mov		ax,word ptr gs:[bx]
	mov		bx,cx
	cmp		ax,word ptr fs:[bx]
	jae		L$196
L$195:
	xor		ax,ax
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
L$196:
	add		word ptr -2[bp],1
	adc		di,0
	jmp		near ptr L$192
L$197:
	mov		word ptr -2[bp],0
	xor		di,di
L$198:
	mov		ax,si
	mov		dx,es
	mov		bx,34H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	cmp		di,ax
	jb		L$199
	jne		L$203
	mov		ax,word ptr -2[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$203
L$199:
	mov		ax,si
	mov		dx,es
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -4[bp],ax
	mov		fs,dx
	mov		ax,word ptr -2[bp]
	mov		dx,di
	mov		bx,16H
	xor		cx,cx
	call		far ptr __I4M
	mov		cx,ax
	mov		word ptr -1eH[bp],dx
	mov		bx,word ptr -4[bp]
	mov		ax,word ptr fs:[bx]
	mov		word ptr -0aH[bp],ax
	mov		ax,word ptr fs:2[bx]
	mov		word ptr -18H[bp],ax
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -18H[bp]
	mov		bx,cx
	mov		cx,word ptr -1eH[bp]
	call		far ptr __PIA
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -14H[bp],ax
	mov		gs,dx
	mov		bx,ax
	mov		ax,word ptr gs:[bx]
	mov		word ptr -20H[bp],ax
	mov		ax,si
	mov		dx,es
	mov		bx,38H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:2[bx],0
	jne		L$200
	mov		ax,word ptr -20H[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$201
L$200:
	mov		ax,word ptr -2[bp]
	or		ax,di
	je		L$202
	mov		ax,word ptr -2[bp]
	add		ax,0ffffH
	mov		dx,di
	adc		dx,0ffffH
	mov		bx,16H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -18H[bp]
	call		far ptr __PIA
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -14H[bp]
	mov		ax,word ptr gs:[bx]
	mov		bx,cx
	cmp		ax,word ptr fs:[bx]
	jae		L$202
L$201:
	xor		ax,ax
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
L$202:
	add		word ptr -2[bp],1
	adc		di,0
	jmp		near ptr L$198
L$203:
	mov		word ptr -2[bp],0
	xor		di,di
L$204:
	mov		ax,si
	mov		dx,es
	mov		bx,38H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:2[bx]
	cmp		di,ax
	jb		L$205
	jne		L$209
	mov		ax,word ptr -2[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$209
L$205:
	mov		ax,si
	mov		dx,es
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr -2[bp]
	mov		word ptr -24H[bp],ax
	mov		word ptr -22H[bp],di
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	mov		ax,word ptr fs:[bx]
	mov		word ptr -10H[bp],ax
	mov		ax,word ptr fs:2[bx]
	mov		word ptr -0eH[bp],ax
	mov		ax,word ptr -10H[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,word ptr -24H[bp]
	mov		cx,word ptr -22H[bp]
	call		far ptr __PIA
	mov		word ptr -8[bp],ax
	mov		gs,dx
	mov		bx,ax
	mov		ax,word ptr gs:[bx]
	mov		word ptr -20H[bp],ax
	mov		ax,si
	mov		dx,es
	mov		bx,40H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:2[bx],0
	jne		L$206
	mov		ax,word ptr -20H[bp]
	cmp		ax,word ptr fs:[bx]
	jae		L$207
L$206:
	mov		ax,word ptr -2[bp]
	or		ax,di
	je		L$208
	mov		ax,word ptr -2[bp]
	add		ax,0ffffH
	mov		dx,di
	adc		dx,0ffffH
	mov		word ptr -24H[bp],ax
	mov		word ptr -22H[bp],dx
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	mov		ax,word ptr -10H[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,word ptr -24H[bp]
	mov		cx,word ptr -22H[bp]
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -8[bp]
	mov		ax,word ptr gs:[bx]
	mov		bx,cx
	cmp		ax,word ptr fs:[bx]
	jae		L$208
L$207:
	xor		ax,ax
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
L$208:
	add		word ptr -2[bp],1
	adc		di,0
	jmp		near ptr L$204
L$209:
	mov		word ptr -2[bp],0
	xor		di,di
L$210:
	mov		ax,si
	mov		dx,es
	mov		bx,30H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		dx,word ptr -2[bp]
	add		dx,1
	mov		ax,di
	adc		ax,0
	cmp		ax,word ptr fs:2[bx]
	jb		L$211
	jne		L$213
	cmp		dx,word ptr fs:[bx]
	jae		L$213
L$211:
	mov		ax,si
	mov		dx,es
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr -2[bp]
	mov		word ptr -24H[bp],ax
	mov		word ptr -22H[bp],di
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	mov		ax,word ptr fs:[bx]
	mov		dx,word ptr fs:2[bx]
	mov		bx,word ptr -24H[bp]
	mov		cx,word ptr -22H[bp]
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:[bx],29H
	jne		L$212
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:[bx]
	mov		word ptr -20H[bp],ax
	mov		ax,si
	mov		dx,es
	mov		bx,34H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		dx,word ptr fs:[bx]
	add		dx,0ffffH
	mov		ax,word ptr fs:2[bx]
	adc		ax,0ffffH
	jne		L$212
	cmp		dx,word ptr -20H[bp]
	ja		L$212
	xor		ax,ax
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
L$212:
	add		word ptr -2[bp],1
	adc		di,0
	jmp		near ptr L$210
L$213:
	mov		word ptr -2[bp],0
	xor		di,di
L$214:
	mov		ax,si
	mov		dx,es
	mov		bx,40H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		dx,word ptr -2[bp]
	add		dx,1
	mov		ax,di
	adc		ax,0
	cmp		ax,word ptr fs:2[bx]
	jb		L$215
	jne		L$217
	cmp		dx,word ptr fs:[bx]
	jae		L$217
L$215:
	mov		ax,si
	mov		dx,es
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr -2[bp]
	mov		word ptr -24H[bp],ax
	mov		word ptr -22H[bp],di
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	shl		word ptr -24H[bp],1
	rcl		word ptr -22H[bp],1
	mov		ax,word ptr fs:[bx]
	mov		dx,word ptr fs:2[bx]
	mov		bx,word ptr -24H[bp]
	mov		cx,word ptr -22H[bp]
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:[bx],35H
	jne		L$216
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr fs:[bx]
	mov		word ptr -20H[bp],ax
	mov		ax,si
	mov		dx,es
	mov		bx,44H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		dx,word ptr fs:[bx]
	add		dx,0ffffH
	mov		ax,word ptr fs:2[bx]
	adc		ax,0ffffH
	jne		L$216
	cmp		dx,word ptr -20H[bp]
	ja		L$216
	xor		ax,ax
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
L$216:
	add		word ptr -2[bp],1
	adc		di,0
	jmp		near ptr L$214
L$217:
	mov		ax,1
L$218:
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
	cld
tsf_load_presets_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,2a4H
	mov		word ptr -68H[bp],ax
	mov		word ptr -66H[bp],dx
	mov		word ptr -22H[bp],bx
	mov		word ptr -20H[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,24H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		si,word ptr es:[bx]
	dec		si
	mov		ax,word ptr -68H[bp]
	mov		dx,word ptr -66H[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],si
	mov		ax,si
	cwd
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __U4M
	call		near ptr sf_alloc_
	les		bx,dword ptr -68H[bp]
	mov		word ptr es:[bx],ax
	mov		word ptr es:2[bx],dx
	mov		ax,word ptr es:[bx]
	test		dx,dx
	jne		L$219
	test		ax,ax
	jne		L$219
	xor		ax,ax
	jmp		near ptr L$278
L$219:
	xor		si,si
	mov		di,word ptr -68H[bp]
L$220:
	mov		ax,word ptr -68H[bp]
	mov		dx,word ptr -66H[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	cmp		si,word ptr es:[bx]
	je		L$221
	mov		ax,si
	cwd
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		es,word ptr -66H[bp]
	mov		ax,word ptr es:[di]
	mov		dx,word ptr es:2[di]
	call		far ptr __PIA
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dword ptr es:[bx],0
	inc		si
	jmp		L$220
L$221:
	les		bx,dword ptr -22H[bp]
	mov		ax,word ptr es:[bx]
	mov		word ptr -54H[bp],ax
	mov		ax,word ptr es:2[bx]
	mov		word ptr -74H[bp],ax
	mov		ax,bx
	mov		dx,es
	mov		bx,24H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,26H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	call		far ptr __PIA
	mov		bx,0ffdaH
	mov		cx,0ffffH
	call		far ptr __PIA
	mov		word ptr -64H[bp],ax
	mov		word ptr -62H[bp],dx
L$222:
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,word ptr -64H[bp]
	mov		cx,word ptr -62H[bp]
	call		far ptr __PTC
	je		L$277
	xor		ax,ax
	mov		word ptr -70H[bp],ax
	mov		word ptr -1aH[bp],ax
	les		di,dword ptr -22H[bp]
	mov		di,word ptr es:[di]
	mov		si,word ptr -22H[bp]
	mov		si,word ptr es:2[si]
L$223:
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -5aH[bp],ax
	mov		word ptr -58H[bp],dx
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,16H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -56H[bp],ax
	mov		word ptr -5cH[bp],dx
	mov		ax,di
	mov		dx,si
	mov		bx,word ptr -64H[bp]
	mov		cx,word ptr -62H[bp]
	call		far ptr __PTC
	je		L$226
	mov		ax,di
	mov		dx,si
	mov		bx,word ptr -54H[bp]
	mov		cx,word ptr -74H[bp]
	call		far ptr __PTC
	je		L$225
	mov		ax,di
	mov		dx,si
	mov		bx,16H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		fs,word ptr -5cH[bp]
	mov		bx,word ptr -56H[bp]
	cmp		ax,word ptr fs:[bx]
	ja		L$225
	mov		ax,word ptr -70H[bp]
	inc		ax
	mov		word ptr -6eH[bp],ax
	mov		bx,cx
	mov		ax,word ptr es:[bx]
	mov		es,word ptr -5cH[bp]
	mov		bx,word ptr -56H[bp]
	cmp		ax,word ptr es:[bx]
	jb		L$224
	mov		ax,di
	mov		dx,si
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	lfs		bx,dword ptr -5aH[bp]
	cmp		ax,word ptr fs:[bx]
	ja		L$225
	mov		bx,cx
	mov		ax,word ptr es:[bx]
	les		bx,dword ptr -5aH[bp]
	cmp		ax,word ptr es:[bx]
	jb		L$224
	mov		ax,di
	mov		dx,si
	mov		bx,word ptr -54H[bp]
	mov		cx,word ptr -74H[bp]
	call		far ptr __PTC
	jae		L$225
L$224:
	mov		ax,word ptr -6eH[bp]
	mov		word ptr -70H[bp],ax
L$225:
	mov		ax,di
	mov		dx,si
	mov		bx,26H
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		si,dx
	jmp		near ptr L$223
L$226:
	mov		ax,word ptr -70H[bp]
	cwd
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	les		si,dword ptr -68H[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		far ptr __PIA
	mov		word ptr -1eH[bp],ax
	mov		word ptr -1cH[bp],dx
	pushd		14H
	mov		bx,word ptr -54H[bp]
	mov		cx,word ptr -74H[bp]
	call		near ptr sf_memcpy_
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,13H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		byte ptr es:[bx],0
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,16H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		fs,word ptr -5cH[bp]
	mov		si,word ptr -56H[bp]
	mov		ax,word ptr fs:[si]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	lfs		si,dword ptr -5aH[bp]
	mov		ax,word ptr fs:[si]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],0
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		si,word ptr es:[bx]
	xor		di,di
	add		si,si
	adc		di,di
	add		si,si
	adc		di,di
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	mov		cx,di
	call		far ptr __PIA
	mov		word ptr -52H[bp],ax
	mov		word ptr -50H[bp],dx
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,3eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		si,word ptr fs:[bx]
	xor		cx,cx
	add		si,si
	adc		cx,cx
	add		si,si
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	call		far ptr __PIA
	mov		word ptr -60H[bp],ax
	mov		word ptr -5eH[bp],dx
L$227:
	mov		ax,word ptr -52H[bp]
	mov		dx,word ptr -50H[bp]
	mov		bx,word ptr -60H[bp]
	mov		cx,word ptr -5eH[bp]
	call		far ptr __PTC
	je		L$241
	mov		byte ptr -14H[bp],0
	mov		byte ptr -0aH[bp],7fH
	mov		byte ptr -0cH[bp],0
	mov		byte ptr -0eH[bp],7fH
	les		si,dword ptr -52H[bp]
	mov		si,word ptr es:[si]
	xor		di,di
	add		si,si
	adc		di,di
	add		si,si
	adc		di,di
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	mov		cx,di
	call		far ptr __PIA
	mov		word ptr -42H[bp],ax
	mov		word ptr -40H[bp],dx
	mov		ax,word ptr -52H[bp]
	mov		dx,word ptr -50H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		si,word ptr fs:[bx]
	xor		cx,cx
	add		si,si
	adc		cx,cx
	add		si,si
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	call		far ptr __PIA
	mov		word ptr -4cH[bp],ax
	mov		word ptr -4aH[bp],dx
L$228:
	mov		ax,word ptr -42H[bp]
	mov		dx,word ptr -40H[bp]
	mov		bx,word ptr -4cH[bp]
	mov		cx,word ptr -4aH[bp]
	call		far ptr __PTC
	je		L$240
	mov		ax,word ptr -42H[bp]
	mov		dx,word ptr -40H[bp]
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		fs,dx
	mov		ax,word ptr -42H[bp]
	mov		dx,word ptr -40H[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	lgs		bx,dword ptr -42H[bp]
	mov		ax,word ptr gs:[bx]
	cmp		ax,2bH
	jne		L$229
	mov		al,byte ptr es:[si]
	mov		byte ptr -14H[bp],al
	mov		al,byte ptr fs:[di]
	mov		byte ptr -0aH[bp],al
	jmp		near ptr L$239
L$229:
	cmp		ax,2cH
	jne		L$230
	mov		al,byte ptr es:[si]
	mov		byte ptr -0cH[bp],al
	mov		al,byte ptr fs:[di]
	mov		byte ptr -0eH[bp],al
	jmp		near ptr L$239
L$230:
	mov		fs,word ptr -40H[bp]
	cmp		word ptr fs:[bx],29H
	jne		L$239
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,34H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		cx,word ptr fs:[bx]
	add		cx,0ffffH
	mov		ax,word ptr fs:2[bx]
	adc		ax,0ffffH
	mov		dx,word ptr es:[si]
	jne		L$231
	cmp		dx,cx
	jae		L$239
L$231:
	mov		ax,dx
	xor		dx,dx
	mov		bx,16H
	xor		cx,cx
	call		far ptr __I4M
	mov		di,ax
	mov		si,dx
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,di
	mov		cx,si
	call		far ptr __PIA
	mov		word ptr -72H[bp],ax
	mov		word ptr -6cH[bp],dx
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		si,word ptr es:[bx]
	xor		di,di
	add		si,si
	adc		di,di
	add		si,si
	adc		di,di
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	mov		cx,di
	call		far ptr __PIA
	mov		word ptr -32H[bp],ax
	mov		word ptr -30H[bp],dx
	mov		ax,word ptr -72H[bp]
	mov		dx,word ptr -6cH[bp]
	mov		bx,2aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		si,word ptr fs:[bx]
	xor		cx,cx
	add		si,si
	adc		cx,cx
	add		si,si
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	call		far ptr __PIA
	mov		word ptr -38H[bp],ax
	mov		word ptr -3eH[bp],dx
L$232:
	mov		ax,word ptr -32H[bp]
	mov		dx,word ptr -30H[bp]
	mov		bx,word ptr -38H[bp]
	mov		cx,word ptr -3eH[bp]
	call		far ptr __PTC
	je		L$239
	mov		byte ptr -6[bp],0
	mov		byte ptr -12H[bp],7fH
	mov		byte ptr -8[bp],0
	mov		byte ptr -10H[bp],7fH
	les		si,dword ptr -32H[bp]
	mov		si,word ptr es:[si]
	xor		di,di
	add		si,si
	adc		di,di
	add		si,si
	adc		di,di
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		fs,dx
	mov		bx,ax
	mov		ax,word ptr fs:[bx]
	mov		dx,word ptr fs:2[bx]
	mov		bx,si
	mov		cx,di
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr -32H[bp]
	mov		dx,word ptr -30H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		gs,dx
	mov		di,word ptr gs:[bx]
	xor		cx,cx
	add		di,di
	adc		cx,cx
	add		di,di
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr fs:[bx]
	mov		dx,word ptr fs:2[bx]
	mov		bx,di
	call		far ptr __PIA
	mov		word ptr -26H[bp],ax
	mov		word ptr -24H[bp],dx
L$233:
	mov		ax,si
	mov		dx,es
	mov		bx,word ptr -26H[bp]
	mov		cx,word ptr -24H[bp]
	call		far ptr __PTC
	je		L$238
	mov		ax,si
	mov		dx,es
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		fs,dx
	mov		ax,si
	mov		dx,es
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		gs,dx
	mov		ax,word ptr es:[si]
	cmp		ax,2bH
	jne		L$234
	mov		al,byte ptr gs:[bx]
	mov		byte ptr -6[bp],al
	mov		al,byte ptr fs:[di]
	mov		byte ptr -12H[bp],al
	jmp		L$237
L$234:
	cmp		ax,2cH
	jne		L$235
	mov		al,byte ptr gs:[bx]
	mov		byte ptr -8[bp],al
	mov		al,byte ptr fs:[di]
	mov		byte ptr -10H[bp],al
	jmp		L$237
L$235:
	cmp		ax,35H
	jne		L$237
	mov		al,byte ptr -12H[bp]
	cmp		al,byte ptr -14H[bp]
	jb		L$237
	mov		al,byte ptr -6[bp]
	cmp		al,byte ptr -0aH[bp]
	ja		L$237
	mov		al,byte ptr -10H[bp]
	cmp		al,byte ptr -0cH[bp]
	jb		L$237
	mov		al,byte ptr -8[bp]
	cmp		al,byte ptr -0eH[bp]
	ja		L$237
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	cmp		word ptr fs:[bx],7fffH
	jne		L$236
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$236:
	inc		word ptr fs:[bx]
L$237:
	mov		ax,si
	mov		dx,es
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	jmp		near ptr L$233
L$238:
	mov		ax,word ptr -32H[bp]
	mov		dx,word ptr -30H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -32H[bp],ax
	mov		word ptr -30H[bp],dx
	jmp		near ptr L$232
L$239:
	mov		ax,word ptr -42H[bp]
	mov		dx,word ptr -40H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -42H[bp],ax
	mov		word ptr -40H[bp],dx
	jmp		near ptr L$228
L$240:
	mov		ax,word ptr -52H[bp]
	mov		dx,word ptr -50H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -52H[bp],ax
	mov		word ptr -50H[bp],dx
	jmp		near ptr L$227
L$241:
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	test		ax,ax
	je		L$276
	cwd
	mov		bx,8aH
	xor		cx,cx
	call		far ptr __U4M
	call		near ptr sf_alloc_
	mov		di,ax
	mov		si,dx
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],di
	mov		word ptr es:2[bx],si
	mov		dx,word ptr es:[bx]
	mov		ax,si
	test		ax,ax
	jne		L$242
	test		dx,dx
	jne		L$242
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$242:
	mov		bx,1
	mov		dx,ss
	lea		ax,-2a8H[bp]
	call		near ptr tsf_region_clear_
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		si,word ptr es:[bx]
	xor		di,di
	add		si,si
	adc		di,di
	add		si,si
	adc		di,di
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	mov		cx,di
	call		far ptr __PIA
	mov		word ptr -52H[bp],ax
	mov		word ptr -50H[bp],dx
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,3eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		si,word ptr fs:[bx]
	xor		cx,cx
	add		si,si
	adc		cx,cx
	add		si,si
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	call		far ptr __PIA
	mov		word ptr -60H[bp],ax
	mov		word ptr -5eH[bp],dx
L$243:
	mov		ax,word ptr -52H[bp]
	mov		dx,word ptr -50H[bp]
	mov		bx,word ptr -60H[bp]
	mov		cx,word ptr -5eH[bp]
	call		far ptr __PTC
	je		L$275
	mov		cx,45H
	mov		ax,ss
	mov		es,ax
	lea		di,-10aH[bp]
	push		ds
	mov		ds,ax
	lea		si,-2a8H[bp]
	rep movsw
	pop		ds
	xor		si,si
	les		bx,dword ptr -52H[bp]
	mov		ax,word ptr es:[bx]
	mov		word ptr -7cH[bp],ax
	mov		word ptr -7aH[bp],si
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,word ptr -7cH[bp]
	mov		cx,word ptr -7aH[bp]
	call		far ptr __PIA
	mov		word ptr -46H[bp],ax
	mov		word ptr -44H[bp],dx
	mov		ax,word ptr -52H[bp]
	mov		dx,word ptr -50H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		di,word ptr fs:[bx]
	xor		cx,cx
	add		di,di
	adc		cx,si
	add		di,di
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,di
	call		far ptr __PIA
	mov		word ptr -48H[bp],ax
	mov		word ptr -4eH[bp],dx
L$244:
	mov		ax,word ptr -46H[bp]
	mov		dx,word ptr -44H[bp]
	mov		bx,word ptr -48H[bp]
	mov		cx,word ptr -4eH[bp]
	call		far ptr __PTC
	je		L$273
	mov		ax,word ptr -46H[bp]
	mov		dx,word ptr -44H[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	lfs		di,dword ptr -46H[bp]
	cmp		word ptr fs:[di],29H
	jne		L$271
	mov		di,word ptr es:[bx]
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,34H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dx,word ptr es:[bx]
	add		dx,0ffffH
	mov		ax,word ptr es:2[bx]
	adc		ax,0ffffH
	jne		L$245
	cmp		di,dx
	jae		L$272
L$245:
	xor		bx,bx
	mov		dx,ss
	lea		ax,-194H[bp]
	call		near ptr tsf_region_clear_
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,di
	cwd
	mov		bx,16H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		far ptr __PIA
	mov		word ptr -36H[bp],ax
	mov		word ptr -34H[bp],dx
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		si,word ptr es:[bx]
	xor		di,di
	add		si,si
	adc		di,di
	add		si,si
	adc		di,di
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	mov		cx,di
	call		far ptr __PIA
	mov		word ptr -2eH[bp],ax
	mov		word ptr -2cH[bp],dx
	mov		ax,word ptr -36H[bp]
	mov		dx,word ptr -34H[bp]
	mov		bx,2aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		si,word ptr fs:[bx]
	xor		cx,cx
	add		si,si
	adc		cx,cx
	add		si,si
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	call		far ptr __PIA
	mov		word ptr -3cH[bp],ax
	mov		word ptr -3aH[bp],dx
L$246:
	mov		ax,word ptr -2eH[bp]
	mov		dx,word ptr -2cH[bp]
	mov		bx,word ptr -3cH[bp]
	mov		cx,word ptr -3aH[bp]
	call		far ptr __PTC
	je		L$270
	mov		cx,45H
	mov		ax,ss
	mov		es,ax
	lea		di,-21eH[bp]
	push		ds
	mov		ds,ax
	lea		si,-194H[bp]
	rep movsw
	pop		ds
	xor		si,si
	les		bx,dword ptr -2eH[bp]
	mov		ax,word ptr es:[bx]
	mov		word ptr -7cH[bp],ax
	mov		word ptr -7aH[bp],si
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -6aH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,word ptr -7cH[bp]
	mov		cx,word ptr -7aH[bp]
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],dx
	mov		ax,word ptr -2eH[bp]
	mov		dx,word ptr -2cH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		di,word ptr fs:[bx]
	xor		cx,cx
	add		di,di
	adc		cx,si
	add		di,di
	adc		cx,cx
	mov		bx,word ptr -6aH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,di
	call		far ptr __PIA
	mov		word ptr -2aH[bp],ax
	mov		word ptr -28H[bp],dx
L$247:
	mov		ax,word ptr -18H[bp]
	mov		dx,word ptr -16H[bp]
	mov		bx,word ptr -2aH[bp]
	mov		cx,word ptr -28H[bp]
	call		far ptr __PTC
	je		L$268
	les		bx,dword ptr -18H[bp]
	cmp		word ptr es:[bx],35H
	jne		L$266
	mov		al,byte ptr -217H[bp]
	cmp		al,byte ptr -104H[bp]
	jb		L$267
	mov		al,byte ptr -218H[bp]
	cmp		al,byte ptr -103H[bp]
	ja		L$267
	mov		al,byte ptr -215H[bp]
	cmp		al,byte ptr -102H[bp]
	jb		L$267
	mov		al,byte ptr -216H[bp]
	cmp		al,byte ptr -101H[bp]
	ja		L$267
	mov		al,byte ptr -104H[bp]
	cmp		al,byte ptr -218H[bp]
	jbe		L$248
	mov		byte ptr -218H[bp],al
L$248:
	mov		al,byte ptr -103H[bp]
	cmp		al,byte ptr -217H[bp]
	jae		L$249
	mov		byte ptr -217H[bp],al
L$249:
	mov		al,byte ptr -102H[bp]
	cmp		al,byte ptr -216H[bp]
	jbe		L$250
	mov		byte ptr -216H[bp],al
L$250:
	mov		al,byte ptr -101H[bp]
	cmp		al,byte ptr -215H[bp]
	jae		L$251
	mov		byte ptr -215H[bp],al
L$251:
	lea		dx,-10aH[bp]
	push		ss
	push		dx
	pushd		0
	xor		bx,bx
	mov		dx,ss
	lea		ax,-21eH[bp]
	call		near ptr tsf_region_operator_
	mov		bx,1
	mov		dx,ss
	lea		ax,-1f0H[bp]
	call		near ptr tsf_region_envtosecs_
	xor		bx,bx
	mov		dx,ss
	lea		ax,-1d0H[bp]
	call		near ptr tsf_region_envtosecs_
	fld		dword ptr -1a4H[bp]
	fcomp		dword ptr DGROUP:L$443
	fnstsw		ax
	sahf
	jae		L$252
	xor		ax,ax
	mov		word ptr -78H[bp],ax
	mov		word ptr -76H[bp],ax
	jmp		L$253
L$252:
	push		dword ptr -1a4H[bp]
	call		near ptr tsf_timecents2Secsf_
	fstp		dword ptr -78H[bp]
L$253:
	mov		ax,word ptr -78H[bp]
	mov		word ptr -1a4H[bp],ax
	mov		ax,word ptr -76H[bp]
	mov		word ptr -1a2H[bp],ax
	fld		dword ptr -19cH[bp]
	fcomp		dword ptr DGROUP:L$443
	fnstsw		ax
	sahf
	jae		L$254
	xor		ax,ax
	mov		word ptr -80H[bp],ax
	mov		word ptr -7eH[bp],ax
	jmp		L$255
L$254:
	push		dword ptr -19cH[bp]
	call		near ptr tsf_timecents2Secsf_
	fstp		dword ptr -80H[bp]
L$255:
	mov		ax,word ptr -80H[bp]
	mov		word ptr -19cH[bp],ax
	mov		ax,word ptr -7eH[bp]
	mov		word ptr -19aH[bp],ax
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,44H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	add		ax,0ffffH
	mov		word ptr -6aH[bp],ax
	mov		di,word ptr es:2[bx]
	adc		di,0ffffH
	mov		ax,word ptr -18H[bp]
	mov		dx,word ptr -16H[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr es:[si]
	test		di,di
	jne		L$256
	cmp		ax,word ptr -6aH[bp]
	jae		L$257
L$256:
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		ax,word ptr -1aH[bp]
	cmp		ax,word ptr fs:[bx]
	jl		L$258
L$257:
	xor		ax,ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
L$258:
	mov		ax,word ptr es:[si]
	cwd
	mov		bx,2eH
	xor		cx,cx
	call		far ptr __I4M
	mov		si,ax
	mov		di,dx
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,20H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,si
	mov		cx,di
	call		far ptr __PIA
	mov		si,ax
	mov		di,dx
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	add		word ptr -212H[bp],ax
	mov		ax,word ptr es:2[bx]
	adc		word ptr -210H[bp],ax
	mov		ax,si
	mov		dx,di
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	add		word ptr -20eH[bp],ax
	mov		ax,word ptr es:2[bx]
	adc		word ptr -20cH[bp],ax
	mov		ax,si
	mov		dx,di
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	add		word ptr -20aH[bp],ax
	mov		ax,word ptr es:2[bx]
	adc		word ptr -208H[bp],ax
	mov		ax,si
	mov		dx,di
	mov		bx,20H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	add		word ptr -206H[bp],ax
	mov		ax,word ptr es:2[bx]
	adc		word ptr -204H[bp],ax
	mov		ax,word ptr es:2[bx]
	or		ax,word ptr es:[bx]
	test		ax,ax
	jbe		L$259
	add		word ptr -206H[bp],0ffffH
	adc		word ptr -204H[bp],0ffffH
L$259:
	mov		ax,word ptr -204H[bp]
	cmp		ax,word ptr 6[bp]
	ja		L$260
	jne		L$261
	mov		ax,word ptr -206H[bp]
	cmp		ax,word ptr 4[bp]
	jbe		L$261
L$260:
	mov		ax,word ptr 4[bp]
	mov		word ptr -206H[bp],ax
	mov		ax,word ptr 6[bp]
	mov		word ptr -204H[bp],ax
L$261:
	cmp		word ptr -1feH[bp],0ffffH
	jne		L$262
	mov		ax,si
	mov		dx,di
	mov		bx,28H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	movzx		ax,byte ptr es:[bx]
	mov		word ptr -1feH[bp],ax
L$262:
	mov		ax,si
	mov		dx,di
	mov		bx,29H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	movsx		ax,byte ptr es:[bx]
	mov		word ptr -1faH[bp],ax
	mov		ax,si
	mov		dx,di
	mov		bx,24H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		word ptr -21cH[bp],ax
	mov		ax,word ptr es:2[bx]
	mov		word ptr -21aH[bp],ax
	mov		ax,word ptr -20cH[bp]
	or		ax,word ptr -20eH[bp]
	je		L$264
	mov		ax,word ptr -20cH[bp]
	cmp		ax,word ptr 6[bp]
	jb		L$263
	jne		L$264
	mov		ax,word ptr -20eH[bp]
	cmp		ax,word ptr 4[bp]
	jae		L$264
L$263:
	add		word ptr -20eH[bp],1
	adc		word ptr -20cH[bp],0
	jmp		L$265
L$264:
	mov		ax,word ptr 4[bp]
	mov		word ptr -20eH[bp],ax
	mov		ax,word ptr 6[bp]
	mov		word ptr -20cH[bp],ax
L$265:
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr -1aH[bp]
	cwd
	mov		bx,8aH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		far ptr __PIA
	mov		cx,45H
	mov		es,dx
	mov		di,ax
	push		ds
	mov		ax,ss
	mov		ds,ax
	lea		si,-21eH[bp]
	rep movsw
	pop		ds
	mov		si,1
	add		word ptr -1aH[bp],si
	jmp		L$267
L$266:
	pushd		0
	mov		ax,bx
	mov		dx,es
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	push		dx
	push		ax
	mov		bx,word ptr -18H[bp]
	mov		bx,word ptr es:[bx]
	mov		dx,ss
	lea		ax,-21eH[bp]
	call		near ptr tsf_region_operator_
L$267:
	mov		ax,word ptr -18H[bp]
	mov		dx,word ptr -16H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],dx
	jmp		near ptr L$247
L$268:
	mov		ax,word ptr -36H[bp]
	mov		dx,word ptr -34H[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		word ptr -7cH[bp],ax
	mov		word ptr -7aH[bp],0
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,word ptr -7cH[bp]
	mov		cx,word ptr -7aH[bp]
	call		far ptr __PIA
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -2eH[bp]
	mov		dx,word ptr -2cH[bp]
	call		far ptr __PTC
	jne		L$269
	test		si,si
	jne		L$269
	mov		cx,45H
	mov		ax,ss
	mov		es,ax
	lea		di,-194H[bp]
	push		ds
	mov		ds,ax
	lea		si,-21eH[bp]
	rep movsw
	pop		ds
L$269:
	mov		ax,word ptr -2eH[bp]
	mov		dx,word ptr -2cH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -2eH[bp],ax
	mov		word ptr -2cH[bp],dx
	jmp		near ptr L$246
L$270:
	mov		si,1
	jmp		L$272
L$271:
	pushd		0
	push		dx
	push		ax
	mov		es,word ptr -44H[bp]
	mov		bx,di
	mov		bx,word ptr es:[bx]
	mov		dx,ss
	lea		ax,-10aH[bp]
	call		near ptr tsf_region_operator_
L$272:
	mov		ax,word ptr -46H[bp]
	mov		dx,word ptr -44H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -46H[bp],ax
	mov		word ptr -44H[bp],dx
	jmp		near ptr L$244
L$273:
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		word ptr -7cH[bp],ax
	mov		word ptr -7aH[bp],0
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	shl		word ptr -7cH[bp],1
	rcl		word ptr -7aH[bp],1
	mov		ax,word ptr -22H[bp]
	mov		dx,word ptr -20H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		bx,word ptr -7cH[bp]
	mov		cx,word ptr -7aH[bp]
	call		far ptr __PIA
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -52H[bp]
	mov		dx,word ptr -50H[bp]
	call		far ptr __PTC
	jne		L$274
	test		si,si
	jne		L$274
	mov		cx,45H
	mov		ax,ss
	mov		es,ax
	lea		di,-2a8H[bp]
	push		ds
	mov		ds,ax
	lea		si,-10aH[bp]
	rep movsw
	pop		ds
L$274:
	mov		ax,word ptr -52H[bp]
	mov		dx,word ptr -50H[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -52H[bp],ax
	mov		word ptr -50H[bp],dx
	jmp		near ptr L$243
L$275:
	mov		ax,word ptr -1eH[bp]
	mov		dx,word ptr -1cH[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -1aH[bp]
	mov		word ptr es:[bx],ax
L$276:
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -74H[bp]
	mov		bx,26H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -54H[bp],ax
	mov		word ptr -74H[bp],dx
	jmp		near ptr L$222
L$277:
	mov		ax,1
L$278:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
	mov		ax,ax
tsf_load_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,0a8H
	mov		si,ax
	mov		word ptr -16H[bp],dx
	xor		ax,ax
	mov		word ptr -4eH[bp],ax
	mov		word ptr -4cH[bp],ax
	mov		word ptr -50H[bp],ax
	mov		word ptr -3aH[bp],ax
	push		dx
	push		si
	mov		cx,ss
	lea		bx,-68H[bp]
	xor		dx,dx
	call		near ptr tsf_riffchunk_read_
	test		al,al
	je		L$335
	mov		al,byte ptr -68H[bp]
	cmp		al,byte ptr DGROUP:L$444
	jne		L$335
	mov		ax,offset DGROUP:L$444
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -67H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$335
	mov		ax,offset DGROUP:L$444
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -66H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$335
	mov		ax,offset DGROUP:L$444
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -65H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$335
	pushd		48H
	xor		bx,bx
	mov		dx,ss
	lea		ax,-0b0H[bp]
	call		near ptr sf_memset_
L$279:
	push		word ptr -16H[bp]
	push		si
	mov		cx,ss
	lea		bx,-60H[bp]
	mov		dx,ss
	lea		ax,-68H[bp]
	call		near ptr tsf_riffchunk_read_
	test		al,al
	je		L$331
	mov		al,byte ptr -60H[bp]
	cmp		al,byte ptr DGROUP:L$445
	jne		L$326
	mov		ax,offset DGROUP:L$445
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -5fH[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$326
	mov		ax,offset DGROUP:L$445
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -5eH[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$326
	mov		ax,offset DGROUP:L$445
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -5dH[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$326
L$280:
	push		word ptr -16H[bp]
	push		si
	mov		cx,ss
	lea		bx,-58H[bp]
	mov		dx,ss
	lea		ax,-60H[bp]
	call		near ptr tsf_riffchunk_read_
	test		al,al
	je		L$279
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$446
	jne		L$285
	mov		ax,offset DGROUP:L$446
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$285
	mov		ax,offset DGROUP:L$446
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$285
	mov		ax,offset DGROUP:L$446
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[di]
	jne		L$285
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,26H
	xor		cx,cx
	call		far ptr __U4D
	or		bx,cx
	jne		L$285
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,26H
	xor		cx,cx
	call		far ptr __U4D
	mov		word ptr -3eH[bp],ax
	mov		word ptr -2eH[bp],dx
	cmp		word ptr -0aeH[bp],0
	jne		L$333
	cmp		word ptr -0b0H[bp],0
	jne		L$333
	mov		ax,dx
	or		ax,word ptr -3eH[bp]
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$281
	cmp		word ptr -3eH[bp],0
	ja		L$333
L$281:
	mov		ax,word ptr -3eH[bp]
	mov		word ptr -8cH[bp],ax
	mov		word ptr -8aH[bp],dx
	mov		bx,26H
	xor		cx,cx
	call		far ptr __U4M
	call		near ptr sf_alloc_
	mov		word ptr -0b0H[bp],ax
	mov		word ptr -0aeH[bp],dx
	test		dx,dx
	jne		L$282
	test		ax,ax
	je		L$333
L$282:
	mov		word ptr -2aH[bp],0
	xor		di,di
L$283:
	mov		ax,word ptr -2eH[bp]
	cmp		di,ax
	jb		L$284
	jne		L$280
	mov		ax,word ptr -2aH[bp]
	cmp		ax,word ptr -3eH[bp]
	jae		L$280
L$284:
	mov		ax,word ptr -2aH[bp]
	mov		dx,di
	mov		bx,26H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -0b0H[bp]
	mov		dx,word ptr -0aeH[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_phdr_
	test		ax,ax
	je		L$333
	add		word ptr -2aH[bp],1
	adc		di,0
	jmp		L$283
L$285:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$447
	jne		L$290
	mov		ax,offset DGROUP:L$447
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$290
	mov		ax,offset DGROUP:L$447
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$290
	mov		ax,offset DGROUP:L$447
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$290
	test		byte ptr -54H[bp],3
	jne		L$290
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	shr		dx,1
	rcr		ax,1
	shr		dx,1
	rcr		ax,1
	mov		word ptr -4aH[bp],ax
	mov		word ptr -38H[bp],dx
	cmp		word ptr -0aaH[bp],0
	jne		L$333
	cmp		word ptr -0acH[bp],0
	jne		L$333
	mov		bx,dx
	or		bx,ax
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$286
	test		ax,ax
	ja		L$333
L$286:
	mov		word ptr -88H[bp],ax
	mov		word ptr -86H[bp],dx
	add		ax,ax
	adc		dx,dx
	add		ax,ax
	adc		dx,dx
	call		near ptr sf_alloc_
	mov		word ptr -0acH[bp],ax
	mov		word ptr -0aaH[bp],dx
	test		dx,dx
	jne		L$287
	test		ax,ax
	je		L$333
L$287:
	xor		ax,ax
	mov		word ptr -0eH[bp],ax
	mov		word ptr -1aH[bp],ax
L$288:
	mov		ax,word ptr -1aH[bp]
	cmp		ax,word ptr -38H[bp]
	jb		L$289
	jne		L$280
	mov		ax,word ptr -0eH[bp]
	cmp		ax,word ptr -4aH[bp]
	jae		L$280
L$289:
	mov		bx,word ptr -0eH[bp]
	mov		cx,word ptr -1aH[bp]
	add		bx,bx
	adc		cx,cx
	add		bx,bx
	adc		cx,cx
	mov		ax,word ptr -0acH[bp]
	mov		dx,word ptr -0aaH[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_pbag_
	test		ax,ax
	je		L$333
	add		word ptr -0eH[bp],1
	adc		word ptr -1aH[bp],0
	jmp		L$288
L$290:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$448
	jne		L$295
	mov		ax,offset DGROUP:L$448
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$295
	mov		ax,offset DGROUP:L$448
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$295
	mov		ax,offset DGROUP:L$448
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$295
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __U4D
	or		bx,cx
	jne		L$295
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __U4D
	mov		word ptr -40H[bp],ax
	mov		word ptr -30H[bp],dx
	cmp		word ptr -0a6H[bp],0
	jne		L$333
	cmp		word ptr -0a8H[bp],0
	jne		L$333
	mov		ax,dx
	or		ax,word ptr -40H[bp]
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$291
	cmp		word ptr -40H[bp],0
	ja		L$333
L$291:
	mov		ax,word ptr -40H[bp]
	mov		word ptr -84H[bp],ax
	mov		word ptr -82H[bp],dx
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __U4M
	call		near ptr sf_alloc_
	mov		word ptr -0a8H[bp],ax
	mov		word ptr -0a6H[bp],dx
	test		dx,dx
	jne		L$292
	test		ax,ax
	je		L$333
L$292:
	mov		word ptr -22H[bp],0
	xor		di,di
L$293:
	mov		ax,word ptr -30H[bp]
	cmp		di,ax
	jb		L$294
	jne		L$280
	mov		ax,word ptr -22H[bp]
	cmp		ax,word ptr -40H[bp]
	jae		L$280
L$294:
	mov		ax,word ptr -22H[bp]
	mov		dx,di
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -0a8H[bp]
	mov		dx,word ptr -0a6H[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_pmod_
	test		ax,ax
	je		L$333
	add		word ptr -22H[bp],1
	adc		di,0
	jmp		L$293
L$295:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$449
	jne		L$300
	mov		ax,offset DGROUP:L$449
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$300
	mov		ax,offset DGROUP:L$449
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$300
	mov		ax,offset DGROUP:L$449
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$300
	test		byte ptr -54H[bp],3
	jne		L$300
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	shr		dx,1
	rcr		ax,1
	shr		dx,1
	rcr		ax,1
	mov		word ptr -44H[bp],ax
	mov		word ptr -0cH[bp],dx
	cmp		word ptr -0a2H[bp],0
	jne		L$333
	cmp		word ptr -0a4H[bp],0
	jne		L$333
	mov		bx,dx
	or		bx,ax
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$296
	test		ax,ax
	ja		L$333
L$296:
	mov		word ptr -80H[bp],ax
	mov		word ptr -7eH[bp],dx
	add		ax,ax
	adc		dx,dx
	add		ax,ax
	adc		dx,dx
	call		near ptr sf_alloc_
	mov		word ptr -0a4H[bp],ax
	mov		word ptr -0a2H[bp],dx
	test		dx,dx
	jne		L$297
	test		ax,ax
	je		L$333
L$297:
	xor		ax,ax
	mov		word ptr -28H[bp],ax
	mov		word ptr -14H[bp],ax
L$298:
	mov		ax,word ptr -14H[bp]
	cmp		ax,word ptr -0cH[bp]
	jb		L$299
	jne		L$280
	mov		ax,word ptr -28H[bp]
	cmp		ax,word ptr -44H[bp]
	jae		L$280
L$299:
	mov		bx,word ptr -28H[bp]
	mov		cx,word ptr -14H[bp]
	add		bx,bx
	adc		cx,cx
	add		bx,bx
	adc		cx,cx
	mov		ax,word ptr -0a4H[bp]
	mov		dx,word ptr -0a2H[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_pgen_
	test		ax,ax
	je		L$333
	add		word ptr -28H[bp],1
	adc		word ptr -14H[bp],0
	jmp		L$298
L$300:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$450
	jne		L$305
	mov		ax,offset DGROUP:L$450
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$305
	mov		ax,offset DGROUP:L$450
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$305
	mov		ax,offset DGROUP:L$450
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$305
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,16H
	xor		cx,cx
	call		far ptr __U4D
	or		bx,cx
	jne		L$305
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,16H
	xor		cx,cx
	call		far ptr __U4D
	mov		word ptr -3cH[bp],ax
	mov		word ptr -32H[bp],dx
	cmp		word ptr -9eH[bp],0
	jne		L$333
	cmp		word ptr -0a0H[bp],0
	jne		L$333
	mov		ax,dx
	or		ax,word ptr -3cH[bp]
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$301
	cmp		word ptr -3cH[bp],0
	ja		L$333
L$301:
	mov		ax,word ptr -3cH[bp]
	mov		word ptr -7cH[bp],ax
	mov		word ptr -7aH[bp],dx
	mov		bx,16H
	xor		cx,cx
	call		far ptr __U4M
	call		near ptr sf_alloc_
	mov		word ptr -0a0H[bp],ax
	mov		word ptr -9eH[bp],dx
	test		dx,dx
	jne		L$302
	test		ax,ax
	je		L$333
L$302:
	mov		word ptr -1cH[bp],0
	xor		di,di
L$303:
	mov		ax,word ptr -32H[bp]
	cmp		di,ax
	jb		L$304
	jne		L$280
	mov		ax,word ptr -1cH[bp]
	cmp		ax,word ptr -3cH[bp]
	jae		L$280
L$304:
	mov		ax,word ptr -1cH[bp]
	mov		dx,di
	mov		bx,16H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -0a0H[bp]
	mov		dx,word ptr -9eH[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_inst_
	test		ax,ax
	je		L$333
	add		word ptr -1cH[bp],1
	adc		di,0
	jmp		L$303
L$305:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$451
	jne		L$310
	mov		ax,offset DGROUP:L$451
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$310
	mov		ax,offset DGROUP:L$451
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$310
	mov		ax,offset DGROUP:L$451
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$310
	test		byte ptr -54H[bp],3
	jne		L$310
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	shr		dx,1
	rcr		ax,1
	shr		dx,1
	rcr		ax,1
	mov		word ptr -46H[bp],ax
	mov		word ptr -34H[bp],dx
	cmp		word ptr -9aH[bp],0
	jne		L$333
	cmp		word ptr -9cH[bp],0
	jne		L$333
	mov		bx,dx
	or		bx,ax
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$306
	test		ax,ax
	ja		L$333
L$306:
	mov		word ptr -78H[bp],ax
	mov		word ptr -76H[bp],dx
	add		ax,ax
	adc		dx,dx
	add		ax,ax
	adc		dx,dx
	call		near ptr sf_alloc_
	mov		word ptr -9cH[bp],ax
	mov		word ptr -9aH[bp],dx
	test		dx,dx
	jne		L$307
	test		ax,ax
	je		L$333
L$307:
	xor		ax,ax
	mov		word ptr -0aH[bp],ax
	mov		word ptr -18H[bp],ax
L$308:
	mov		ax,word ptr -18H[bp]
	cmp		ax,word ptr -34H[bp]
	jb		L$309
	jne		L$280
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr -46H[bp]
	jae		L$280
L$309:
	mov		bx,word ptr -0aH[bp]
	mov		cx,word ptr -18H[bp]
	add		bx,bx
	adc		cx,cx
	add		bx,bx
	adc		cx,cx
	mov		ax,word ptr -9cH[bp]
	mov		dx,word ptr -9aH[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_ibag_
	test		ax,ax
	je		L$333
	add		word ptr -0aH[bp],1
	adc		word ptr -18H[bp],0
	jmp		L$308
L$310:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$452
	jne		L$315
	mov		ax,offset DGROUP:L$452
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$315
	mov		ax,offset DGROUP:L$452
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$315
	mov		ax,offset DGROUP:L$452
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$315
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __U4D
	or		bx,cx
	jne		L$315
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __U4D
	mov		word ptr -42H[bp],ax
	mov		word ptr -26H[bp],dx
	cmp		word ptr -96H[bp],0
	jne		L$333
	cmp		word ptr -98H[bp],0
	jne		L$333
	mov		ax,dx
	or		ax,word ptr -42H[bp]
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$311
	cmp		word ptr -42H[bp],0
	ja		L$333
L$311:
	mov		ax,word ptr -42H[bp]
	mov		word ptr -74H[bp],ax
	mov		word ptr -72H[bp],dx
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __U4M
	call		near ptr sf_alloc_
	mov		word ptr -98H[bp],ax
	mov		word ptr -96H[bp],dx
	test		dx,dx
	jne		L$312
	test		ax,ax
	je		L$333
L$312:
	mov		word ptr -20H[bp],0
	xor		di,di
L$313:
	mov		ax,word ptr -26H[bp]
	cmp		di,ax
	jb		L$314
	jne		L$280
	mov		ax,word ptr -20H[bp]
	cmp		ax,word ptr -42H[bp]
	jae		L$280
L$314:
	mov		ax,word ptr -20H[bp]
	mov		dx,di
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -98H[bp]
	mov		dx,word ptr -96H[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_imod_
	test		ax,ax
	je		L$333
	add		word ptr -20H[bp],1
	adc		di,0
	jmp		L$313
L$315:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$453
	jne		L$320
	mov		ax,offset DGROUP:L$453
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$320
	mov		ax,offset DGROUP:L$453
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$320
	mov		ax,offset DGROUP:L$453
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$320
	test		byte ptr -54H[bp],3
	jne		L$320
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	shr		dx,1
	rcr		ax,1
	shr		dx,1
	rcr		ax,1
	mov		word ptr -48H[bp],ax
	mov		word ptr -36H[bp],dx
	cmp		word ptr -92H[bp],0
	jne		L$333
	cmp		word ptr -94H[bp],0
	jne		L$333
	mov		bx,dx
	or		bx,ax
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$316
	test		ax,ax
	ja		L$333
L$316:
	mov		word ptr -70H[bp],ax
	mov		word ptr -6eH[bp],dx
	add		ax,ax
	adc		dx,dx
	add		ax,ax
	adc		dx,dx
	call		near ptr sf_alloc_
	mov		word ptr -94H[bp],ax
	mov		word ptr -92H[bp],dx
	test		dx,dx
	jne		L$317
	test		ax,ax
	je		L$333
L$317:
	xor		ax,ax
	mov		word ptr -12H[bp],ax
	mov		word ptr -10H[bp],ax
L$318:
	mov		ax,word ptr -10H[bp]
	cmp		ax,word ptr -36H[bp]
	jb		L$319
	jne		L$280
	mov		ax,word ptr -12H[bp]
	cmp		ax,word ptr -48H[bp]
	jae		L$280
L$319:
	mov		bx,word ptr -12H[bp]
	mov		cx,word ptr -10H[bp]
	add		bx,bx
	adc		cx,cx
	add		bx,bx
	adc		cx,cx
	mov		ax,word ptr -94H[bp]
	mov		dx,word ptr -92H[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_igen_
	test		ax,ax
	je		L$333
	add		word ptr -12H[bp],1
	adc		word ptr -10H[bp],0
	jmp		L$318
L$320:
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$454
	jne		L$325
	mov		ax,offset DGROUP:L$454
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$325
	mov		ax,offset DGROUP:L$454
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$325
	mov		ax,offset DGROUP:L$454
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$325
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,2eH
	xor		cx,cx
	call		far ptr __U4D
	or		bx,cx
	jne		L$325
	mov		ax,word ptr -54H[bp]
	mov		dx,word ptr -52H[bp]
	mov		bx,2eH
	xor		cx,cx
	call		far ptr __U4D
	mov		word ptr -24H[bp],ax
	mov		word ptr -2cH[bp],dx
	cmp		word ptr -8eH[bp],0
	jne		L$333
	cmp		word ptr -90H[bp],0
	jne		L$333
	mov		ax,dx
	or		ax,word ptr -24H[bp]
	je		L$333
	cmp		dx,1
	ja		L$333
	jne		L$321
	cmp		word ptr -24H[bp],0
	ja		L$333
L$321:
	mov		ax,word ptr -24H[bp]
	mov		word ptr -6cH[bp],ax
	mov		word ptr -6aH[bp],dx
	mov		bx,2eH
	xor		cx,cx
	call		far ptr __U4M
	call		near ptr sf_alloc_
	mov		word ptr -90H[bp],ax
	mov		word ptr -8eH[bp],dx
	test		dx,dx
	jne		L$322
	test		ax,ax
	je		L$333
L$322:
	mov		word ptr -1eH[bp],0
	xor		di,di
L$323:
	mov		ax,word ptr -2cH[bp]
	cmp		di,ax
	jb		L$324
	jne		L$280
	mov		ax,word ptr -1eH[bp]
	cmp		ax,word ptr -24H[bp]
	jae		L$280
L$324:
	mov		ax,word ptr -1eH[bp]
	mov		dx,di
	mov		bx,2eH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -90H[bp]
	mov		dx,word ptr -8eH[bp]
	call		far ptr __PIA
	mov		bx,si
	mov		cx,word ptr -16H[bp]
	call		near ptr tsf_hydra_read_shdr_
	test		ax,ax
	je		L$333
	add		word ptr -1eH[bp],1
	adc		di,0
	jmp		L$323
L$325:
	mov		ax,si
	mov		dx,word ptr -16H[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		fs,word ptr -16H[bp]
	mov		ax,word ptr fs:[si]
	mov		dx,word ptr fs:2[si]
	mov		bx,word ptr -54H[bp]
	mov		cx,word ptr -52H[bp]
	call		dword ptr es:[di]
	jmp		near ptr L$280
L$326:
	mov		al,byte ptr -60H[bp]
	cmp		al,byte ptr DGROUP:L$455
	jne		L$330
	mov		ax,offset DGROUP:L$455
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -5fH[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$330
	mov		ax,offset DGROUP:L$455
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -5eH[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$330
	mov		ax,offset DGROUP:L$455
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -5dH[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$330
L$327:
	push		word ptr -16H[bp]
	push		si
	mov		cx,ss
	lea		bx,-58H[bp]
	mov		dx,ss
	lea		ax,-60H[bp]
	call		near ptr tsf_riffchunk_read_
	test		al,al
	je		L$279
	mov		al,byte ptr -58H[bp]
	cmp		al,byte ptr DGROUP:L$456
	jne		L$329
	mov		ax,offset DGROUP:L$456
	mov		dx,ds
	mov		bx,1
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -57H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$329
	mov		ax,offset DGROUP:L$456
	mov		dx,ds
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -56H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$329
	mov		ax,offset DGROUP:L$456
	mov		dx,ds
	mov		bx,3
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		al,byte ptr -55H[bp]
	cmp		al,byte ptr es:[bx]
	jne		L$329
	mov		ax,word ptr -3aH[bp]
	or		ax,word ptr -50H[bp]
	jne		L$329
	cmp		word ptr -52H[bp],0
	jne		L$328
	cmp		word ptr -54H[bp],2
	jb		L$329
L$328:
	test		byte ptr -54H[bp],1
	jne		L$333
	mov		ax,si
	mov		dx,word ptr -16H[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		fs,word ptr -16H[bp]
	mov		ax,word ptr fs:[si]
	mov		dx,word ptr fs:2[si]
	mov		bx,word ptr -54H[bp]
	mov		cx,word ptr -52H[bp]
	call		dword ptr es:[di]
	test		ax,ax
	je		L$333
	mov		di,word ptr -54H[bp]
	mov		cx,word ptr -52H[bp]
	shr		cx,1
	rcr		di,1
	mov		word ptr -50H[bp],di
	mov		word ptr -3aH[bp],cx
	jmp		near ptr L$327
L$329:
	mov		ax,si
	mov		dx,word ptr -16H[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		fs,word ptr -16H[bp]
	mov		ax,word ptr fs:[si]
	mov		dx,word ptr fs:2[si]
	mov		bx,word ptr -54H[bp]
	mov		cx,word ptr -52H[bp]
	call		dword ptr es:[di]
	jmp		near ptr L$327
L$330:
	mov		ax,si
	mov		dx,word ptr -16H[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		es,dx
	mov		fs,word ptr -16H[bp]
	mov		ax,word ptr fs:[si]
	mov		dx,word ptr fs:2[si]
	mov		bx,word ptr -5cH[bp]
	mov		cx,word ptr -5aH[bp]
	call		dword ptr es:[di]
	jmp		near ptr L$279
L$331:
	mov		ax,word ptr -3aH[bp]
	or		ax,word ptr -50H[bp]
	je		L$334
	mov		dx,ss
	lea		ax,-0b0H[bp]
	call		near ptr tsf_valid_hydra_
	test		ax,ax
	je		L$334
	mov		ax,0aH
	xor		dx,dx
	call		near ptr sf_alloc_
	mov		si,ax
	mov		di,dx
	mov		word ptr -4eH[bp],ax
	mov		word ptr -4cH[bp],dx
	test		dx,dx
	jne		L$332
	test		ax,ax
	je		L$333
L$332:
	pushd		0aH
	xor		bx,bx
	call		near ptr sf_memset_
	push		word ptr -3aH[bp]
	push		word ptr -50H[bp]
	mov		cx,ss
	lea		bx,-0b0H[bp]
	mov		ax,si
	mov		dx,di
	call		near ptr tsf_load_presets_
	test		ax,ax
	je		L$333
	mov		ax,si
	mov		dx,di
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -50H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -3aH[bp]
	mov		word ptr es:2[bx],ax
	jmp		L$334
L$333:
	mov		ax,word ptr -4eH[bp]
	mov		dx,word ptr -4cH[bp]
	call		near ptr tsf_close_
	xor		ax,ax
	mov		word ptr -4eH[bp],ax
	mov		word ptr -4cH[bp],ax
L$334:
	mov		ax,word ptr -0b0H[bp]
	mov		dx,word ptr -0aeH[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -0acH[bp]
	mov		dx,word ptr -0aaH[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -0a8H[bp]
	mov		dx,word ptr -0a6H[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -0a4H[bp]
	mov		dx,word ptr -0a2H[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -0a0H[bp]
	mov		dx,word ptr -9eH[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -9cH[bp]
	mov		dx,word ptr -9aH[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -98H[bp]
	mov		dx,word ptr -96H[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -94H[bp]
	mov		dx,word ptr -92H[bp]
	call		near ptr sf_free_
	mov		ax,word ptr -90H[bp]
	mov		dx,word ptr -8eH[bp]
	call		near ptr sf_free_
L$335:
	mov		ax,word ptr -4eH[bp]
	mov		dx,word ptr -4cH[bp]
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
	mov		ax,ax
tsf_close_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,2
	mov		si,ax
	mov		word ptr -0aH[bp],dx
	test		dx,dx
	jne		L$336
	test		ax,ax
	je		L$341
L$336:
	mov		es,dx
	mov		dx,word ptr es:[si]
	mov		ax,word ptr es:2[si]
	test		ax,ax
	jne		L$337
	test		dx,dx
	je		L$340
L$337:
	xor		di,di
L$338:
	mov		ax,si
	mov		dx,word ptr -0aH[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	cmp		di,word ptr es:[bx]
	jge		L$339
	mov		ax,di
	cwd
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		es,word ptr -0aH[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		far ptr __PIA
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	call		near ptr sf_free_
	inc		di
	jmp		L$338
L$339:
	mov		es,word ptr -0aH[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		near ptr sf_free_
L$340:
	mov		ax,si
	mov		dx,word ptr -0aH[bp]
	call		near ptr sf_free_
L$341:
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
	mov		ax,ax
	cld
sf_file_read_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		di,ax
	mov		es,dx
	mov		word ptr -0eH[bp],bx
	mov		word ptr -0cH[bp],cx
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		word ptr -6[bp],dx
	mov		ax,di
	mov		dx,es
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0aH[bp],ax
	mov		word ptr -8[bp],dx
	mov		ax,word ptr 8[bp]
	mov		fs,word ptr -6[bp]
	cmp		ax,word ptr fs:2[si]
	ja		L$342
	jne		L$343
	mov		ax,word ptr 6[bp]
	cmp		ax,word ptr fs:[si]
	jbe		L$343
L$342:
	mov		es,dx
	mov		si,word ptr -0aH[bp]
	mov		word ptr es:[si],7
	xor		ax,ax
	xor		dx,dx
	jmp		L$346
L$343:
	push		word ptr es:[di]
	push		dword ptr -0eH[bp]
	push		dword ptr 6[bp]
	call		far ptr _HREAD
	cmp		dx,word ptr 8[bp]
	jne		L$344
	cmp		ax,word ptr 6[bp]
	je		L$345
L$344:
	les		si,dword ptr -0aH[bp]
	mov		word ptr es:[si],7
	xor		ax,ax
	xor		dx,dx
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	retf		4
L$345:
	mov		ax,word ptr 6[bp]
	mov		es,word ptr -6[bp]
	sub		word ptr es:[si],ax
	mov		ax,word ptr 8[bp]
	sbb		word ptr es:2[si],ax
	mov		ax,word ptr 6[bp]
	mov		dx,word ptr 8[bp]
L$346:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	retf		4
	mov		ax,ax
	cld
sf_file_skip_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		di,ax
	mov		es,dx
	mov		word ptr -0aH[bp],bx
	mov		word ptr -8[bp],cx
	mov		word ptr -0eH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		word ptr -6[bp],dx
	mov		ax,word ptr -8[bp]
	mov		fs,dx
	cmp		ax,word ptr fs:2[si]
	ja		L$348
	jne		L$347
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr fs:[si]
	ja		L$348
L$347:
	push		word ptr es:[di]
	push		dword ptr -0aH[bp]
	push		1
	call		far ptr _LLSEEK
	test		dx,dx
	jge		L$349
L$348:
	mov		ax,word ptr -0eH[bp]
	mov		dx,word ptr -0cH[bp]
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		word ptr es:[si],7
	xor		ax,ax
	jmp		L$350
L$349:
	mov		ax,word ptr -0aH[bp]
	mov		es,word ptr -6[bp]
	sub		word ptr es:[si],ax
	mov		ax,word ptr -8[bp]
	sbb		word ptr es:2[si],ax
	mov		ax,1
L$350:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	retf
	mov		ax,ax
	cld
sf_load_sample_blocks_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,24H
	mov		word ptr -26H[bp],ax
	mov		word ptr -24H[bp],dx
	mov		word ptr -1aH[bp],bx
	mov		word ptr -16H[bp],cx
	mov		bx,6
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		si,word ptr es:[bx]
	mov		word ptr -0aH[bp],si
	mov		ax,word ptr es:2[bx]
	mov		word ptr -8[bp],ax
	mov		word ptr -6[bp],0
	mov		ax,word ptr -26H[bp]
	mov		dx,word ptr -24H[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -16H[bp]
	cmp		ax,word ptr es:2[bx]
	ja		L$351
	jne		L$352
	mov		ax,word ptr -1aH[bp]
	cmp		ax,word ptr es:[bx]
	jbe		L$352
L$351:
	mov		ax,7
	jmp		near ptr L$372
L$352:
	mov		ax,word ptr -1aH[bp]
	add		ax,2
	mov		word ptr -18H[bp],ax
	mov		ax,word ptr -16H[bp]
	adc		ax,0
	mov		word ptr -14H[bp],ax
	mov		ax,word ptr -1aH[bp]
	add		ax,1
	mov		bx,word ptr -16H[bp]
	adc		bx,0
	xor		dx,dx
	add		bx,1
	adc		dx,dx
	add		bx,bx
	adc		dx,dx
	add		bx,bx
	adc		dx,dx
	jne		L$353
	cmp		bx,0fff0H
	jbe		L$354
L$353:
	mov		ax,3
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$354:
	mov		ax,word ptr -18H[bp]
	add		ax,0ffffH
	mov		si,word ptr -14H[bp]
	adc		si,0ffffH
	shr		si,6
	add		si,1
	mov		ax,bx
	call		near ptr sf_alloc_
	les		bx,dword ptr -0aH[bp]
	mov		word ptr es:4[bx],ax
	mov		word ptr es:6[bx],dx
	mov		ax,si
	xor		dx,dx
	add		ax,si
	adc		dx,dx
	add		ax,ax
	adc		dx,dx
	call		near ptr sf_alloc_
	mov		es,word ptr -8[bp]
	mov		word ptr es:8[bx],ax
	mov		word ptr es:0aH[bx],dx
	mov		dx,word ptr es:4[bx]
	mov		ax,word ptr es:6[bx]
	test		ax,ax
	jne		L$355
	test		dx,dx
	je		L$356
L$355:
	mov		dx,word ptr es:8[bx]
	mov		ax,word ptr es:0aH[bx]
	test		ax,ax
	jne		L$357
	test		dx,dx
	jne		L$357
L$356:
	mov		ax,4
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$357:
	mov		ax,word ptr -14H[bp]
	or		ax,word ptr -18H[bp]
	je		L$370
	mov		ax,word ptr -14H[bp]
	cmp		ax,40H
	ja		L$358
	jne		L$359
	cmp		word ptr -18H[bp],0
	jbe		L$359
L$358:
	xor		di,di
	mov		si,40H
	jmp		L$360
L$359:
	mov		di,word ptr -18H[bp]
	mov		si,ax
L$360:
	mov		word ptr -12H[bp],di
	mov		word ptr -0cH[bp],si
	mov		ax,di
	add		ax,0fff8H
	mov		dx,si
	adc		dx,0
	call		near ptr sf_alloc_
	mov		word ptr -1cH[bp],ax
	mov		word ptr -22H[bp],dx
	test		dx,dx
	jne		L$361
	test		ax,ax
	jne		L$361
	mov		ax,4
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$361:
	les		bx,dword ptr -0aH[bp]
	mov		cx,word ptr es:0eH[bx]
	mov		bx,cx
	shl		bx,2
	mov		word ptr -28H[bp],bx
	inc		cx
	mov		bx,word ptr -0aH[bp]
	mov		word ptr es:0eH[bx],cx
	mov		cx,word ptr es:8[bx]
	mov		es,word ptr es:0aH[bx]
	mov		bx,cx
	add		bx,word ptr -28H[bp]
	mov		word ptr es:[bx],ax
	mov		word ptr es:2[bx],dx
	mov		bx,0fff8H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -10H[bp],ax
	mov		word ptr -0eH[bp],dx
	test		ax,ax
	je		L$362
	mov		ax,3
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$362:
	mov		ax,word ptr -16H[bp]
	cmp		si,ax
	ja		L$363
	jne		L$364
	cmp		di,word ptr -1aH[bp]
	jbe		L$364
L$363:
	mov		di,word ptr -1aH[bp]
	mov		si,ax
L$364:
	mov		word ptr -20H[bp],di
	mov		word ptr -1eH[bp],si
	mov		ax,si
	or		ax,di
	je		L$366
	push		si
	push		di
	mov		bx,word ptr -10H[bp]
	mov		cx,word ptr -0eH[bp]
	mov		ax,word ptr -26H[bp]
	mov		dx,word ptr -24H[bp]
	push		cs
	call		near ptr sf_file_read_
	cmp		dx,si
	jne		L$365
	cmp		ax,di
	je		L$366
L$365:
	mov		ax,7
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$366:
	xor		di,di
	xor		si,si
L$367:
	mov		ax,word ptr -0cH[bp]
	cmp		si,ax
	jb		L$368
	jne		L$369
	cmp		di,word ptr -12H[bp]
	jae		L$369
L$368:
	mov		ax,word ptr -10H[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,di
	mov		cx,si
	call		far ptr __PIA
	mov		bx,word ptr -6[bp]
	shl		bx,2
	mov		word ptr -28H[bp],bx
	les		bx,dword ptr -0aH[bp]
	mov		cx,word ptr es:4[bx]
	mov		es,word ptr es:6[bx]
	inc		word ptr -6[bp]
	mov		bx,cx
	add		bx,word ptr -28H[bp]
	mov		word ptr es:[bx],ax
	mov		word ptr es:2[bx],dx
	add		di,0
	adc		si,1
	jmp		L$367
L$369:
	mov		ax,word ptr -1cH[bp]
	mov		dx,word ptr -22H[bp]
	call		near ptr sf_pin_
	test		ax,ax
	je		L$371
	mov		ax,word ptr -20H[bp]
	sub		word ptr -1aH[bp],ax
	mov		ax,word ptr -1eH[bp]
	sbb		word ptr -16H[bp],ax
	mov		ax,word ptr -12H[bp]
	sub		word ptr -18H[bp],ax
	mov		ax,word ptr -0cH[bp]
	sbb		word ptr -14H[bp],ax
	jmp		near ptr L$357
L$370:
	les		bx,dword ptr -0aH[bp]
	mov		ax,word ptr es:4[bx]
	mov		dx,word ptr es:6[bx]
	call		near ptr sf_pin_
	test		ax,ax
	je		L$371
	mov		ax,1
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$371:
	mov		ax,5
L$372:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
sf_file_samples_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,2
	mov		si,ax
	mov		di,dx
	call		near ptr sf_load_sample_blocks_
	mov		word ptr -6[bp],ax
	cmp		ax,1
	je		L$373
	mov		ax,si
	mov		dx,di
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr -6[bp]
	mov		word ptr es:[si],ax
	xor		ax,ax
L$373:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	retf
sf_read_font_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,24H
	mov		word ptr -0cH[bp],bx
	mov		word ptr -0aH[bp],cx
	mov		dword ptr -8[bp],0
	push		dx
	push		ax
	push		40H
	call		far ptr _LOPEN
	mov		word ptr -18H[bp],ax
	cmp		ax,0ffffH
	jne		L$374
	les		si,dword ptr 4[bp]
	mov		word ptr es:[si],6
	xor		ax,ax
	xor		dx,dx
	jmp		near ptr L$381
L$374:
	push		ax
	pushd		0
	push		2
	call		far ptr _LLSEEK
	mov		di,ax
	mov		si,dx
	mov		word ptr -0eH[bp],2
	test		dx,dx
	jge		L$375
	mov		word ptr -0eH[bp],7
	jmp		near ptr L$379
L$375:
	test		dx,dx
	jg		L$376
	jne		L$379
	cmp		ax,0cH
	jb		L$379
L$376:
	cmp		dx,7fffH
	jl		L$377
	jne		L$379
	cmp		ax,0fff0H
	ja		L$379
L$377:
	push		word ptr -18H[bp]
	pushd		0
	push		0
	call		far ptr _LLSEEK
	or		ax,dx
	je		L$378
	mov		word ptr -0eH[bp],7
	jmp		L$379
L$378:
	mov		word ptr -16H[bp],di
	mov		word ptr -14H[bp],si
	mov		ax,word ptr -0cH[bp]
	mov		word ptr -12H[bp],ax
	mov		ax,word ptr -0aH[bp]
	mov		word ptr -10H[bp],ax
	mov		word ptr -0eH[bp],0
	lea		dx,-18H[bp]
	mov		word ptr -28H[bp],dx
	mov		word ptr -26H[bp],ss
	mov		word ptr -24H[bp],offset sf_file_read_
	mov		word ptr -22H[bp],seg sf_file_read_
	mov		word ptr -20H[bp],offset sf_file_skip_
	mov		word ptr -1eH[bp],seg sf_file_skip_
	mov		word ptr -1cH[bp],offset sf_file_samples_
	mov		word ptr -1aH[bp],seg sf_file_samples_
	mov		dx,ss
	lea		ax,-28H[bp]
	call		near ptr tsf_load_
	mov		word ptr -8[bp],ax
	mov		word ptr -6[bp],dx
	cmp		word ptr -0eH[bp],0
	je		L$379
	call		near ptr tsf_close_
	xor		ax,ax
	mov		word ptr -8[bp],ax
	mov		word ptr -6[bp],ax
L$379:
	push		word ptr -18H[bp]
	call		far ptr _LCLOSE
	mov		ax,word ptr -0eH[bp]
	test		ax,ax
	jne		L$380
	mov		ax,2
L$380:
	les		si,dword ptr 4[bp]
	mov		word ptr es:[si],ax
	mov		ax,word ptr -8[bp]
	mov		dx,word ptr -6[bp]
L$381:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
sf_quantize_:
	push		bp
	mov		bp,sp
	sub		sp,10H
	mov		ax,word ptr 0cH[bp]
	mov		word ptr -8[bp],ax
	mov		ax,word ptr 0eH[bp]
	mov		word ptr -6[bp],ax
	fild		dword ptr -8[bp]
	fcomp		qword ptr 4[bp]
	fnstsw		ax
	sahf
	jb		L$382
	mov		ax,word ptr 0cH[bp]
	mov		word ptr -4[bp],ax
	mov		ax,word ptr 0eH[bp]
	mov		word ptr -2[bp],ax
	jmp		L$386
L$382:
	mov		ax,word ptr 10H[bp]
	mov		word ptr -8[bp],ax
	mov		ax,word ptr 12H[bp]
	mov		word ptr -6[bp],ax
	fild		dword ptr -8[bp]
	fcomp		qword ptr 4[bp]
	fnstsw		ax
	sahf
	ja		L$383
	mov		ax,word ptr 10H[bp]
	mov		word ptr -4[bp],ax
	mov		ax,word ptr 12H[bp]
	mov		word ptr -2[bp],ax
	mov		ax,word ptr -4[bp]
	mov		dx,word ptr -2[bp]
	leave
	ret		10H
L$383:
	fldz
	fcomp		qword ptr 4[bp]
	fnstsw		ax
	sahf
	jbe		L$384
	fld		qword ptr 4[bp]
	fadd		qword ptr DGROUP:L$458
	jmp		L$385
L$384:
	fld		qword ptr 4[bp]
	fadd		qword ptr DGROUP:L$457
L$385:
	fstp		qword ptr -10H[bp]
	fld		qword ptr -10H[bp]
	call		far ptr __CHP
	fistp		dword ptr -4[bp]
L$386:
	mov		ax,word ptr -4[bp]
	mov		dx,word ptr -2[bp]
	leave
	ret		10H
	mov		ax,ax
sf_frames_:
	push		bp
	mov		bp,sp
	push		bx
	sub		sp,4
	push		0ffH
	push		0ffffH
	pushd		0
	mov		ax,word ptr 0cH[bp]
	mov		word ptr -6[bp],ax
	mov		word ptr -4[bp],0
	fild		dword ptr -6[bp]
	fmul		qword ptr 4[bp]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	lea		sp,-2[bp]
	pop		bx
	pop		bp
	ret		0aH
	cld
sf_prepare_env_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,20H
	mov		si,ax
	mov		word ptr -6[bp],dx
	mov		di,bx
	mov		word ptr -8[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	fstp		qword ptr -24H[bp]
	push		word ptr 4[bp]
	mov		es,word ptr -8[bp]
	fld		dword ptr es:[di]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_frames_
	mov		es,word ptr -6[bp]
	mov		word ptr es:[si],ax
	mov		word ptr es:2[si],dx
	push		word ptr 4[bp]
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_frames_
	mov		word ptr -12H[bp],ax
	mov		word ptr -14H[bp],dx
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -14H[bp]
	mov		word ptr es:2[bx],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	test		word ptr es:2[bx],7fffH
	jne		L$387
	cmp		word ptr es:[bx],0
	je		L$388
L$387:
	xor		ax,ax
	mov		word ptr -10H[bp],ax
	mov		word ptr -0aH[bp],ax
	jmp		L$389
L$388:
	push		word ptr 4[bp]
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_frames_
	mov		word ptr -10H[bp],ax
	mov		word ptr -0aH[bp],dx
L$389:
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -10H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0aH[bp]
	mov		word ptr es:2[bx],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	test		word ptr es:2[bx],7fffH
	jne		L$390
	cmp		word ptr es:[bx],0
	je		L$391
L$390:
	xor		ax,ax
	mov		word ptr -0eH[bp],ax
	mov		word ptr -0cH[bp],ax
	jmp		L$392
L$391:
	push		word ptr 4[bp]
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_frames_
	mov		word ptr -0eH[bp],ax
	mov		word ptr -0cH[bp],dx
L$392:
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -0eH[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0cH[bp]
	mov		word ptr es:2[bx],ax
	push		word ptr 4[bp]
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_frames_
	mov		word ptr -12H[bp],ax
	mov		word ptr -14H[bp],dx
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -14H[bp]
	mov		word ptr es:2[bx],ax
	or		ax,word ptr es:[bx]
	jne		L$393
	mov		ax,word ptr 4[bp]
	xor		dx,dx
	mov		cx,64H
	div		cx
	mov		word ptr es:[bx],ax
	mov		word ptr es:2[bx],0
L$393:
	push		0
	push		7fffH
	push		0ffffH
	push		8000H
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -12H[bp],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:[bx],ax
	push		0
	push		7fffH
	push		0ffffH
	push		8000H
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -12H[bp],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,16H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:[bx],ax
	push		0
	push		7fffH
	push		0ffffH
	push		8000H
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -12H[bp],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:[bx],ax
	push		0
	push		7fffH
	push		0ffffH
	push		8000H
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		di,ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,1aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],di
	push		0
	push		8000H
	pushd		0
	fld		qword ptr -24H[bp]
	fmul		qword ptr DGROUP:L$459
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		di,ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],di
	fldz
	fcomp		qword ptr -24H[bp]
	fnstsw		ax
	sahf
	jae		L$394
	fld		qword ptr -24H[bp]
	call		far ptr `IF@DLOG`
	fchs
	fstp		qword ptr -1cH[bp]
	jmp		L$395
L$394:
	mov		dword ptr -18H[bp],402273b6H
	mov		dword ptr -1cH[bp],45a1cac1H
L$395:
	push		1
	pushd		0
	push		0
	fld		qword ptr -1cH[bp]
	fdiv		qword ptr DGROUP:L$460
	fmul		qword ptr DGROUP:L$459
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		di,ax
	mov		word ptr -12H[bp],dx
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,20H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],di
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:2[bx],ax
	push		0
	push		640H
	pushd		0
	fld		qword ptr -1cH[bp]
	fmul		qword ptr DGROUP:L$461
	fld		qword ptr DGROUP:L$462
	call		far ptr `IF@DLOG`
	fdivp		st(1),st
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		di,ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		word ptr es:[bx],di
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		2
	mov		ax,ax
sf_lfo_step_:
	push		bp
	mov		bp,sp
	push		bx
	sub		sp,0eH
	mov		word ptr -4[bp],ax
	fild		word ptr -4[bp]
	fdiv		qword ptr DGROUP:L$463
	fld		qword ptr DGROUP:L$464
	call		far ptr `IF@DPOW`
	fmul		qword ptr DGROUP:L$465
	fstp		qword ptr -10H[bp]
	push		40H
	pushd		0
	push		0
	fld		qword ptr -10H[bp]
	fmul		qword ptr DGROUP:L$466
	mov		word ptr -8[bp],dx
	mov		word ptr -6[bp],0
	fild		dword ptr -8[bp]
	fdivp		st(1),st
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	lea		sp,-2[bp]
	pop		bx
	pop		bp
	ret
	mov		ax,ax
	cld
sf_prepare_filter_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,38H
	mov		si,ax
	mov		di,dx
	mov		word ptr -8[bp],bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,70H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0aH[bp],ax
	mov		word ptr -10H[bp],dx
	mov		es,dx
	mov		bx,ax
	fild		word ptr es:[bx]
	fdiv		qword ptr DGROUP:L$467
	fld		qword ptr DGROUP:L$468
	call		far ptr `IF@DPOW`
	fmul		qword ptr DGROUP:L$469
	mov		ax,word ptr 4[bp]
	mov		word ptr -14H[bp],ax
	mov		word ptr -12H[bp],0
	fild		dword ptr -14H[bp]
	fdivp		st(1),st
	fstp		qword ptr -1cH[bp]
	mov		ax,word ptr -8[bp]
	mov		dx,word ptr -6[bp]
	mov		bx,6eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		bx,word ptr es:[bx]
	neg		bx
	mov		word ptr -0cH[bp],bx
	fild		word ptr -0cH[bp]
	fdiv		qword ptr DGROUP:L$470
	fld		qword ptr DGROUP:L$471
	call		far ptr `IF@DPOW`
	fmul		qword ptr DGROUP:L$472
	fstp		qword ptr -3cH[bp]
	mov		ax,si
	mov		dx,di
	mov		bx,80H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		fs,word ptr -10H[bp]
	mov		bx,word ptr -0aH[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	push		1
	push		6a0aH
	pushd		0
	push		dword ptr -38H[bp]
	push		dword ptr -3cH[bp]
	call		near ptr sf_quantize_
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0eH[bp],dx
	mov		ax,si
	mov		dx,di
	mov		bx,74H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		ax,word ptr -0cH[bp]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0eH[bp]
	mov		word ptr es:2[bx],ax
	mov		fs,word ptr -10H[bp]
	mov		bx,word ptr -0aH[bp]
	cmp		word ptr fs:[bx],34bcH
	jg		L$396
	fld		qword ptr -1cH[bp]
	fcomp		qword ptr DGROUP:L$473
	fnstsw		ax
	sahf
	jb		L$397
L$396:
	mov		ax,si
	mov		dx,di
	mov		bx,70H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dword ptr es:[bx],0
	mov		ax,word ptr es:[bx]
	mov		word ptr -0aH[bp],ax
	mov		ax,word ptr es:2[bx]
	mov		word ptr -0cH[bp],ax
	mov		ax,si
	mov		dx,di
	mov		bx,6cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -0aH[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0cH[bp]
	mov		word ptr es:2[bx],ax
	mov		ax,word ptr es:[bx]
	mov		word ptr -0cH[bp],ax
	mov		ax,word ptr es:2[bx]
	mov		word ptr -10H[bp],ax
	mov		ax,si
	mov		dx,di
	mov		bx,68H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -0cH[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -10H[bp]
	jmp		near ptr L$398
L$397:
	fld		qword ptr -1cH[bp]
	fmul		qword ptr DGROUP:L$474
	call		far ptr `IF@DTAN`
	fst		qword ptr -34H[bp]
	fmul		qword ptr -34H[bp]
	fstp		qword ptr -2cH[bp]
	mov		bx,cx
	fild		dword ptr es:[bx]
	fmul		qword ptr -34H[bp]
	fmul		qword ptr DGROUP:L$475
	fstp		qword ptr -3cH[bp]
	fld1
	fadd		qword ptr -3cH[bp]
	fadd		qword ptr -2cH[bp]
	fdivr		qword ptr DGROUP:L$476
	fstp		qword ptr -24H[bp]
	push		1000H
	pushd		0
	push		1
	fld		qword ptr -2cH[bp]
	fmul		qword ptr -24H[bp]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -10H[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		ax,si
	mov		dx,di
	mov		bx,68H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -10H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0aH[bp]
	mov		word ptr es:2[bx],ax
	push		2000H
	push		0
	push		0e000H
	push		0
	fld		qword ptr -2cH[bp]
	fadd		qword ptr DGROUP:L$477
	fmul		qword ptr DGROUP:L$468
	fmul		qword ptr -24H[bp]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0eH[bp],dx
	mov		ax,si
	mov		dx,di
	mov		bx,6cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -0cH[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0eH[bp]
	mov		word ptr es:2[bx],ax
	push		1000H
	push		0
	push		0f000H
	push		0
	fld1
	fsub		qword ptr -3cH[bp]
	fadd		qword ptr -2cH[bp]
	fmul		qword ptr -24H[bp]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		ax,si
	mov		dx,di
	mov		bx,70H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -0aH[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -0cH[bp]
L$398:
	mov		word ptr es:2[bx],ax
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		2
	cld
sf_prepare_region_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,2aH
	mov		di,ax
	mov		word ptr -8[bp],dx
	mov		si,bx
	mov		word ptr -6[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,20H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fild		word ptr es:[bx]
	fmul		qword ptr DGROUP:L$478
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,24H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fild		word ptr es:[bx]
	fsubrp		st(1),st
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,22H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -16H[bp],ax
	mov		word ptr -1aH[bp],dx
	mov		es,dx
	mov		bx,ax
	fild		word ptr es:[bx]
	fmulp		st(1),st
	fdiv		qword ptr DGROUP:L$478
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fild		word ptr es:[bx]
	fmul		qword ptr DGROUP:L$478
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fild		word ptr es:[bx]
	faddp		st(1),st
	faddp		st(1),st
	fstp		qword ptr -2eH[bp]
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		word ptr -26H[bp],ax
	mov		ax,word ptr es:2[bx]
	mov		word ptr -24H[bp],ax
	xor		ax,ax
	mov		word ptr -22H[bp],ax
	mov		word ptr -20H[bp],ax
	fild		qword ptr -26H[bp]
	mov		ax,word ptr 4[bp]
	mov		word ptr -1eH[bp],ax
	mov		word ptr -1cH[bp],0
	fild		dword ptr -1eH[bp]
	fdivp		st(1),st
	call		far ptr `IF@DLOG`
	fmul		qword ptr DGROUP:L$479
	fld		qword ptr DGROUP:L$480
	call		far ptr `IF@DLOG`
	fdivp		st(1),st
	fadd		qword ptr -2eH[bp]
	fstp		qword ptr -2eH[bp]
	push		0
	push		7fffH
	push		0ffffH
	push		8000H
	push		dword ptr -2aH[bp]
	push		dword ptr -2eH[bp]
	call		near ptr sf_quantize_
	mov		word ptr -18H[bp],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,78H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,7aH
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		fs,word ptr -1aH[bp]
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0eH[bp],ax
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	mov		fs,word ptr -8[bp]
	mov		word ptr fs:[di],ax
	mov		word ptr fs:2[di],dx
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -10H[bp],ax
	mov		word ptr -0cH[bp],dx
	mov		ax,di
	mov		dx,fs
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		gs,word ptr -0cH[bp]
	mov		bx,word ptr -10H[bp]
	mov		ax,word ptr gs:[bx]
	mov		dx,word ptr gs:2[bx]
	mov		bx,cx
	mov		word ptr fs:[bx],ax
	mov		word ptr fs:2[bx],dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,96H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		fs,dx
	mov		gs,word ptr -6[bp]
	mov		al,byte ptr gs:[si]
	mov		byte ptr fs:[bx],al
	mov		ax,si
	mov		dx,gs
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -0aH[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		gs,dx
	mov		bx,word ptr -0aH[bp]
	mov		ax,word ptr fs:[bx]
	mov		dx,word ptr fs:2[bx]
	mov		bx,cx
	mov		word ptr gs:[bx],ax
	mov		word ptr gs:2[bx],dx
	mov		gs,word ptr -6[bp]
	cmp		word ptr gs:[si],0
	je		L$402
	mov		bx,word ptr -0aH[bp]
	mov		dx,word ptr fs:[bx]
	mov		ax,word ptr fs:2[bx]
	mov		bx,word ptr -0eH[bp]
	cmp		ax,word ptr es:2[bx]
	ja		L$399
	jne		L$402
	cmp		dx,word ptr es:[bx]
	jb		L$402
L$399:
	mov		ax,si
	mov		dx,gs
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -0aH[bp]
	mov		dx,word ptr fs:[bx]
	mov		ax,word ptr fs:2[bx]
	mov		bx,cx
	cmp		ax,word ptr es:2[bx]
	jb		L$400
	jne		L$402
	cmp		dx,word ptr es:[bx]
	jae		L$402
L$400:
	mov		dx,word ptr es:[bx]
	mov		ax,word ptr es:2[bx]
	mov		fs,word ptr -0cH[bp]
	mov		bx,word ptr -10H[bp]
	cmp		ax,word ptr fs:2[bx]
	jb		L$401
	jne		L$402
	cmp		dx,word ptr fs:[bx]
	jae		L$402
L$401:
	mov		bx,cx
	mov		ax,word ptr es:[bx]
	mov		word ptr -14H[bp],ax
	mov		ax,word ptr es:2[bx]
	jmp		L$403
L$402:
	xor		ax,ax
	mov		word ptr -14H[bp],ax
L$403:
	mov		word ptr -12H[bp],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -14H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -12H[bp]
	mov		word ptr es:2[bx],ax
	push		0
	push		4000H
	push		0ffffH
	push		0c000H
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,2aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	fmul		dword ptr DGROUP:L$481
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -1aH[bp],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,7cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -1aH[bp]
	mov		word ptr es:[bx],ax
	push		0
	push		5dcH
	push		0ffffH
	push		0fdc0H
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,26H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	fmul		qword ptr DGROUP:L$482
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,6eH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -16H[bp],ax
	mov		word ptr -18H[bp],dx
	mov		es,dx
	mov		bx,ax
	fild		word ptr es:[bx]
	fmul		qword ptr DGROUP:L$483
	faddp		st(1),st
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -1aH[bp],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,7eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -1aH[bp]
	mov		word ptr es:[bx],ax
	push		0
	push		8000H
	pushd		0
	mov		es,word ptr -18H[bp]
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr es:[bx]
	neg		ax
	mov		word ptr -16H[bp],ax
	fild		word ptr -16H[bp]
	fdiv		qword ptr DGROUP:L$484
	fld		qword ptr DGROUP:L$482
	call		far ptr `IF@DPOW`
	fmul		qword ptr DGROUP:L$485
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_quantize_
	mov		word ptr -18H[bp],ax
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,90H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,8eH
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -18H[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,6
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -1aH[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,92H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -1aH[bp]
	mov		al,byte ptr fs:[bx]
	mov		bx,cx
	mov		byte ptr es:[bx],al
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,7
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,93H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -18H[bp]
	mov		al,byte ptr fs:[bx]
	mov		bx,cx
	mov		byte ptr es:[bx],al
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,94H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -18H[bp]
	mov		al,byte ptr fs:[bx]
	mov		bx,cx
	mov		byte ptr es:[bx],al
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,9
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		es,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,95H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -18H[bp]
	mov		al,byte ptr es:[bx]
	mov		bx,cx
	mov		byte ptr fs:[bx],al
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,72H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,82H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -18H[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,74H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		es,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,84H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -18H[bp]
	mov		ax,word ptr es:[bx]
	mov		bx,cx
	mov		word ptr fs:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,76H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,86H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -18H[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,80H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		es,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,88H
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -18H[bp]
	mov		ax,word ptr es:[bx]
	mov		bx,cx
	mov		word ptr fs:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,78H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,8aH
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -18H[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,88H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		fs,dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,8cH
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -18H[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	push		word ptr 4[bp]
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,7aH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_frames_
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,58H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -16H[bp]
	mov		word ptr es:2[bx],ax
	push		word ptr 4[bp]
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,82H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	fld		dword ptr es:[bx]
	sub		sp,8
	mov		bx,sp
	fstp		qword ptr ss:[bx]
	call		near ptr sf_frames_
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,5cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -16H[bp]
	mov		word ptr es:2[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,7eH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr 4[bp]
	call		near ptr sf_lfo_step_
	mov		word ptr -16H[bp],ax
	mov		word ptr -18H[bp],dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,60H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -16H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:2[bx],ax
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,86H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr 4[bp]
	call		near ptr sf_lfo_step_
	mov		word ptr -16H[bp],ax
	mov		word ptr -18H[bp],dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,64H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -16H[bp]
	mov		word ptr es:[bx],ax
	mov		ax,word ptr -18H[bp]
	mov		word ptr es:2[bx],ax
	push		word ptr 4[bp]
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,2eH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -16H[bp],ax
	mov		word ptr -18H[bp],dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,word ptr -16H[bp]
	mov		cx,word ptr -18H[bp]
	call		near ptr sf_prepare_env_
	push		word ptr 4[bp]
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,4eH
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],dx
	mov		ax,di
	mov		dx,word ptr -8[bp]
	mov		bx,34H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,word ptr -18H[bp]
	mov		cx,word ptr -16H[bp]
	call		near ptr sf_prepare_env_
	push		word ptr 4[bp]
	mov		bx,si
	mov		cx,word ptr -6[bp]
	mov		ax,di
	mov		dx,word ptr -8[bp]
	call		near ptr sf_prepare_filter_
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		2
sf_alloc_preset_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0eH
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		word ptr -10H[bp],bx
	mov		word ptr -0eH[bp],cx
	mov		ax,bx
	mov		dx,cx
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	cwd
	mov		bx,98H
	xor		cx,cx
	call		far ptr __U4M
	mov		di,ax
	mov		si,dx
	mov		ax,word ptr -10H[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,16H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -12H[bp],ax
	mov		es,dx
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,6
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		fs,dx
	mov		bx,word ptr -12H[bp]
	mov		ax,word ptr es:[bx]
	mov		bx,cx
	mov		word ptr fs:[bx],ax
	mov		ax,word ptr -10H[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,14H
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -12H[bp],ax
	mov		fs,dx
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		cx,ax
	mov		es,dx
	mov		bx,word ptr -12H[bp]
	mov		ax,word ptr fs:[bx]
	mov		bx,cx
	mov		word ptr es:[bx],ax
	mov		ax,si
	or		ax,di
	je		L$412
	test		si,si
	jne		L$404
	cmp		di,0fff0H
	jbe		L$405
L$404:
	mov		ax,3
	jmp		near ptr L$413
L$405:
	mov		ax,di
	mov		dx,si
	call		near ptr sf_alloc_
	les		bx,dword ptr -0cH[bp]
	mov		word ptr es:[bx],ax
	mov		word ptr es:2[bx],dx
	mov		dx,word ptr es:[bx]
	mov		ax,word ptr es:2[bx]
	test		ax,ax
	jne		L$406
	test		dx,dx
	jne		L$406
	mov		ax,4
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		6
L$406:
	mov		word ptr -8[bp],0
L$407:
	mov		ax,word ptr -10H[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,1cH
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -8[bp]
	cmp		ax,word ptr es:[bx]
	jge		L$411
	mov		ax,word ptr -10H[bp]
	mov		dx,word ptr -0eH[bp]
	mov		bx,18H
	xor		cx,cx
	call		far ptr __PIA
	mov		si,ax
	mov		es,dx
	mov		ax,word ptr -8[bp]
	cwd
	mov		bx,8aH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		far ptr __PIA
	mov		si,ax
	mov		word ptr -6[bp],dx
	mov		bx,2
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		di,word ptr es:2[bx]
	or		di,word ptr es:[bx]
	je		L$410
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,0cH
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		fs,dx
	mov		ax,si
	mov		dx,word ptr -6[bp]
	mov		bx,10H
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		dx,word ptr fs:[di]
	mov		ax,word ptr fs:2[di]
	cmp		ax,word ptr es:2[bx]
	ja		L$410
	jne		L$408
	cmp		dx,word ptr es:[bx]
	jae		L$410
L$408:
	mov		ax,word ptr es:2[bx]
	cmp		ax,word ptr 6[bp]
	ja		L$410
	jne		L$409
	mov		ax,word ptr es:[bx]
	cmp		ax,word ptr 4[bp]
	ja		L$410
L$409:
	push		word ptr 8[bp]
	mov		ax,word ptr -0cH[bp]
	mov		dx,word ptr -0aH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		di,ax
	mov		word ptr -12H[bp],dx
	mov		es,dx
	imul		cx,word ptr es:[di],98H
	les		bx,dword ptr -0cH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	add		ax,cx
	mov		bx,si
	mov		cx,word ptr -6[bp]
	call		near ptr sf_prepare_region_
	mov		es,word ptr -12H[bp]
	inc		word ptr es:[di]
L$410:
	inc		word ptr -8[bp]
	jmp		near ptr L$407
L$411:
	les		bx,dword ptr -0cH[bp]
	mov		ax,word ptr es:[bx]
	mov		dx,word ptr es:2[bx]
	call		near ptr sf_pin_
	test		ax,ax
	jne		L$412
	mov		ax,5
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		6
L$412:
	mov		ax,1
L$413:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		6
	cld
sf_unload_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	mov		si,ax
	mov		cx,dx
	mov		es,dx
	mov		dx,word ptr es:[si]
	mov		ax,word ptr es:2[si]
	test		ax,ax
	jne		L$414
	test		dx,dx
	je		L$417
L$414:
	xor		bx,bx
L$415:
	mov		es,cx
	cmp		bx,word ptr es:0cH[si]
	jae		L$416
	imul		di,bx,0aH
	les		ax,dword ptr es:[si]
	add		di,ax
	mov		ax,word ptr es:[di]
	mov		dx,word ptr es:2[di]
	call		near ptr sf_free_
	inc		bx
	jmp		L$415
L$416:
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		near ptr sf_free_
L$417:
	xor		bx,bx
L$418:
	mov		es,cx
	cmp		bx,word ptr es:0eH[si]
	jae		L$419
	mov		ax,bx
	shl		ax,2
	les		di,dword ptr es:8[si]
	add		di,ax
	mov		ax,word ptr es:[di]
	mov		dx,word ptr es:2[di]
	call		near ptr sf_free_
	inc		bx
	jmp		L$418
L$419:
	mov		ax,word ptr es:8[si]
	mov		dx,word ptr es:0aH[si]
	call		near ptr sf_free_
	mov		es,cx
	mov		ax,word ptr es:4[si]
	mov		dx,word ptr es:6[si]
	call		near ptr sf_free_
	pushd		10H
	xor		bx,bx
	mov		ax,si
	mov		dx,cx
	call		near ptr sf_memset_
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	retf
	mov		ax,ax
	cld
sf_load_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,16H
	mov		word ptr -14H[bp],ax
	mov		di,dx
	mov		si,bx
	mov		word ptr -8[bp],cx
	mov		word ptr -1aH[bp],2
	mov		word ptr -0eH[bp],0
	call		far ptr GETWINFLAGS
	test		ah,4
	jne		L$420
	mov		ax,2
	jmp		near ptr L$432
L$420:
	lea		dx,-1aH[bp]
	push		ss
	push		dx
	mov		bx,si
	mov		cx,word ptr -8[bp]
	mov		ax,word ptr -14H[bp]
	mov		dx,di
	call		near ptr sf_read_font_
	mov		di,ax
	mov		word ptr -0aH[bp],dx
	test		dx,dx
	jne		L$421
	test		ax,ax
	je		L$430
L$421:
	mov		word ptr -1aH[bp],3
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		word ptr -12H[bp],ax
	mov		word ptr -10H[bp],dx
	mov		es,dx
	mov		bx,ax
	mov		ax,word ptr es:[bx]
	cwd
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __U4M
	mov		bx,dx
	or		bx,ax
	je		L$429
	test		dx,dx
	jne		L$429
	cmp		ax,0fff0H
	ja		L$429
	call		near ptr sf_alloc_
	mov		es,word ptr -8[bp]
	mov		word ptr es:[si],ax
	mov		word ptr es:2[si],dx
	mov		ax,word ptr es:[si]
	test		dx,dx
	jne		L$422
	test		ax,ax
	jne		L$422
	mov		word ptr -1aH[bp],4
	jmp		near ptr L$429
L$422:
	les		bx,dword ptr -12H[bp]
	mov		ax,word ptr es:[bx]
	mov		es,word ptr -8[bp]
	mov		word ptr es:0cH[si],ax
	mov		word ptr -6[bp],0
L$423:
	mov		ax,di
	mov		dx,word ptr -0aH[bp]
	mov		bx,8
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr -6[bp]
	cmp		ax,word ptr es:[bx]
	jge		L$425
	push		word ptr 6[bp]
	mov		ax,di
	mov		dx,word ptr -0aH[bp]
	mov		bx,4
	xor		cx,cx
	call		far ptr __PIA
	mov		bx,ax
	mov		es,dx
	push		dword ptr es:[bx]
	mov		ax,word ptr -6[bp]
	cwd
	mov		bx,1eH
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		es,word ptr -0aH[bp]
	mov		ax,word ptr es:[di]
	mov		dx,word ptr es:2[di]
	call		far ptr __PIA
	imul		bx,word ptr -6[bp],0aH
	mov		word ptr -0cH[bp],bx
	mov		es,word ptr -8[bp]
	mov		bx,word ptr es:[si]
	mov		cx,word ptr es:2[si]
	mov		word ptr -18H[bp],cx
	mov		cx,word ptr -0cH[bp]
	add		cx,bx
	mov		word ptr -16H[bp],cx
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -16H[bp]
	mov		dx,word ptr -18H[bp]
	call		near ptr sf_alloc_preset_
	mov		word ptr -1aH[bp],ax
	cmp		ax,1
	jne		L$429
	mov		es,word ptr -8[bp]
	les		bx,dword ptr es:[si]
	add		bx,word ptr -0cH[bp]
	cmp		word ptr es:4[bx],0
	je		L$424
	mov		word ptr -0eH[bp],ax
L$424:
	inc		word ptr -6[bp]
	jmp		near ptr L$423
L$425:
	cmp		word ptr -0eH[bp],0
	jne		L$426
	mov		word ptr -1aH[bp],3
	jmp		L$429
L$426:
	mov		es,word ptr -8[bp]
	mov		ax,word ptr es:[si]
	mov		dx,word ptr es:2[si]
	call		near ptr sf_pin_
	test		ax,ax
	je		L$427
	mov		ax,1
	jmp		L$428
L$427:
	mov		ax,5
L$428:
	mov		word ptr -1aH[bp],ax
L$429:
	mov		ax,di
	mov		dx,word ptr -0aH[bp]
	call		near ptr tsf_close_
	cmp		word ptr -1aH[bp],1
	je		L$431
L$430:
	mov		ax,si
	mov		dx,word ptr -8[bp]
	push		cs
	call		near ptr sf_unload_
L$431:
	mov		ax,word ptr -1aH[bp]
L$432:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	retf		2
SFLOAD_TEXT		ENDS
CONST		SEGMENT	WORD PUBLIC USE16 'DATA'
L$433:
    DB	0, 0, 96H, 44H, 0, 0, 0, 0
L$434:
    DB	0, 0, 0, 0, 0, 0, 0, 40H
L$435:
    DB	0, 0, 0c8H, 0c2H
L$436:
    DB	0cdH, 0ccH, 4cH, 3dH
L$437:
    DB	0, 0, 0, 0, 0, 0, 24H, 40H
L$438:
    DB	52H, 49H, 46H, 46H, 0
L$439:
    DB	4cH, 49H, 53H, 54H, 0, 0, 0
L$440:
    DB	0, 0b8H, 3aH, 0c6H
L$441:
    DB	0, 0, 7aH, 44H
L$442:
    DB	0, 0, 20H, 41H
L$443:
    DB	0, 0b8H, 3aH, 0c6H
L$444:
    DB	73H, 66H, 62H, 6bH, 0
L$445:
    DB	70H, 64H, 74H, 61H, 0
L$446:
    DB	70H, 68H, 64H, 72H, 0
L$447:
    DB	70H, 62H, 61H, 67H, 0
L$448:
    DB	70H, 6dH, 6fH, 64H, 0
L$449:
    DB	70H, 67H, 65H, 6eH, 0
L$450:
    DB	69H, 6eH, 73H, 74H, 0
L$451:
    DB	69H, 62H, 61H, 67H, 0
L$452:
    DB	69H, 6dH, 6fH, 64H, 0
L$453:
    DB	69H, 67H, 65H, 6eH, 0
L$454:
    DB	73H, 68H, 64H, 72H, 0
L$455:
    DB	73H, 64H, 74H, 61H, 0
L$456:
    DB	73H, 6dH, 70H, 6cH, 0, 0, 0, 0
L$457:
    DB	0, 0, 0, 0, 0, 0, 0e0H, 3fH
L$458:
    DB	0, 0, 0, 0, 0, 0, 0e0H, 0bfH
L$459:
    DB	0, 0, 0, 0, 0, 0, 0e0H, 40H
L$460:
    DB	0c1H, 0caH, 0a1H, 45H, 0b6H, 73H, 22H, 40H
L$461:
    DB	0, 0, 0, 0, 0, 0, 69H, 40H
L$462:
    DB	0, 0, 0, 0, 0, 0, 24H, 40H
L$463:
    DB	0, 0, 0, 0, 0, 0c0H, 92H, 40H
L$464:
    DB	0, 0, 0, 0, 0, 0, 0, 40H
L$465:
    DB	27H, 31H, 8, 0acH, 1cH, 5aH, 20H, 40H
L$466:
    DB	0, 0, 0, 0, 0, 0, 70H, 41H
L$467:
    DB	0, 0, 0, 0, 0, 0c0H, 92H, 40H
L$468:
    DB	0, 0, 0, 0, 0, 0, 0, 40H
L$469:
    DB	27H, 31H, 8, 0acH, 1cH, 5aH, 20H, 40H
L$470:
    DB	0, 0, 0, 0, 0, 0, 69H, 40H
L$471:
    DB	0, 0, 0, 0, 0, 0, 24H, 40H
L$472:
    DB	0, 0, 0, 0, 0a0H, 0a0H, 0f6H, 40H
L$473:
    DB	56H, 0eH, 2dH, 0b2H, 9dH, 0efH, 0dfH, 3fH
L$474:
    DB	18H, 2dH, 44H, 54H, 0fbH, 21H, 9, 40H
L$475:
    DB	0, 0, 0, 0, 0, 0, 0f0H, 3eH
L$476:
    DB	0, 0, 0, 0, 0, 0, 0b0H, 41H
L$477:
    DB	0, 0, 0, 0, 0, 0, 0f0H, 0bfH
L$478:
    DB	0, 0, 0, 0, 0, 0, 59H, 40H
L$479:
    DB	0, 0, 0, 0, 0, 0c0H, 92H, 40H
L$480:
    DB	0, 0, 0, 0, 0, 0, 0, 40H
L$481:
    DB	0, 0, 0, 47H, 0, 0, 0, 0
L$482:
    DB	0, 0, 0, 0, 0, 0, 24H, 40H
L$483:
    DB	0, 0, 0, 0, 0, 0, 0e0H, 3fH
L$484:
    DB	0, 0, 0, 0, 0, 0, 79H, 40H
L$485:
    DB	0, 0, 0, 0, 0, 0, 0e0H, 40H

CONST		ENDS
CONST2		SEGMENT	WORD PUBLIC USE16 'DATA'
L$486:
    DB	3, 0, 0cH, 0, 3, 0, 10H, 0
    DB	3, 0, 14H, 0, 3, 0, 18H, 0
    DB	4, 0, 0cH, 0, 12H, 0, 80H, 0
    DB	12H, 0, 88H, 0, 12H, 0, 72H, 0
    DB	22H, 0, 70H, 0, 32H, 0, 6eH, 0
    DB	12H, 0, 76H, 0, 12H, 0, 74H, 0
    DB	4, 0, 10H, 0, 42H, 0, 78H, 0
    DB	0, 0, 0, 0, 0, 0, 0, 0
    DB	0, 0, 0, 0, 91H, 0, 2aH, 0
    DB	0, 0, 0, 0, 0, 0, 0, 0
    DB	0, 0, 0, 0, 61H, 0, 7aH, 0
    DB	52H, 0, 7eH, 0, 61H, 0, 82H, 0
    DB	52H, 0, 86H, 0, 61H, 0, 4eH, 0
    DB	71H, 0, 52H, 0, 61H, 0, 56H, 0
    DB	71H, 0, 5aH, 0, 0b1H, 0, 5eH, 0
    DB	71H, 0, 62H, 0, 81H, 0, 66H, 0
    DB	81H, 0, 6aH, 0, 61H, 0, 2eH, 0
    DB	71H, 0, 32H, 0, 61H, 0, 36H, 0
    DB	71H, 0, 3aH, 0, 0c1H, 0, 3eH, 0
    DB	71H, 0, 42H, 0, 81H, 0, 46H, 0
    DB	81H, 0, 4aH, 0, 0, 0, 0, 0
    DB	0, 0, 0, 0, 5, 0, 0, 0
    DB	6, 0, 0, 0, 4, 0, 14H, 0
    DB	0, 0, 0, 0, 0, 0, 0, 0
    DB	0a1H, 0, 26H, 0, 0, 0, 0, 0
    DB	4, 0, 18H, 0, 2, 0, 1cH, 0
    DB	2, 0, 1eH, 0, 0, 0, 0, 0
    DB	7, 0, 0, 0, 0, 0, 0, 0
    DB	2, 0, 22H, 0, 8, 0, 0aH, 0
    DB	9, 0, 20H, 0

CONST2		ENDS
_DATA		SEGMENT	WORD PUBLIC USE16 'DATA'
_DATA		ENDS
		END
