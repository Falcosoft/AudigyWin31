.387
.386p
		PUBLIC	LIBMAIN
		PUBLIC	SFCORE
		EXTRN	__I4M:BYTE
		EXTRN	__U4M:BYTE
		EXTRN	sf_load_:BYTE
		EXTRN	sf_unload_:BYTE
		EXTRN	__DLLstart_:BYTE
DGROUP		GROUP	CONST,CONST2,_DATA,_BSS
SFIRQ_TEXT		SEGMENT	PARA PUBLIC USE16 'CODE'
		ASSUME CS:SFIRQ_TEXT, DS:DGROUP, SS:DGROUP
sf_clip_:
	push		bp
	mov		bp,sp
	cmp		dx,cx
	jl		L$1
	jne		L$2
	cmp		ax,bx
	jae		L$2
L$1:
	mov		ax,bx
	mov		dx,cx
	jmp		L$4
L$2:
	cmp		dx,word ptr 6[bp]
	jg		L$3
	jne		L$4
	cmp		ax,word ptr 4[bp]
	jbe		L$4
L$3:
	mov		ax,word ptr 4[bp]
	mov		dx,word ptr 6[bp]
L$4:
	pop		bp
	ret		4
	mov		ax,ax
	cld
sf_ratio_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,6
	mov		si,ax
	mov		di,dx
	cmp		dx,0ffffH
	jl		L$5
	jne		L$6
	cmp		ax,8ad0H
	ja		L$6
L$5:
	xor		ax,ax
	xor		dx,dx
	jmp		near ptr L$14
L$6:
	test		dx,dx
	jg		L$7
	jne		L$8
	cmp		ax,20d0H
	jb		L$8
L$7:
	mov		ax,0ffffH
	mov		dx,7fffH
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
L$8:
	mov		bx,4b0H
	xor		cx,cx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],ax
	cwd
	xor		cx,cx
	call		far ptr __I4M
	sub		si,ax
	sbb		di,dx
	test		di,di
	jge		L$9
	add		si,4b0H
	mov		ax,word ptr -0cH[bp]
	dec		ax
	mov		word ptr -0aH[bp],ax
L$9:
	mov		ax,si
	xor		dx,dx
	mov		bx,0aH
	div		bx
	mov		di,ax
	mov		ax,si
	xor		dx,dx
	div		bx
	mov		bx,dx
	mov		si,di
	shl		si,2
	mov		ax,word ptr _sf_pitch_table[si]
	mov		word ptr -0eH[bp],ax
	mov		di,word ptr _sf_pitch_table+2[si]
	mov		ax,word ptr _sf_pitch_table+4[si]
	mov		dx,word ptr _sf_pitch_table+6[si]
	sub		ax,word ptr -0eH[bp]
	sbb		dx,di
	xor		cx,cx
	call		far ptr __U4M
	mov		bx,0aH
	xor		cx,cx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	add		ax,word ptr -0eH[bp]
	adc		dx,di
	cmp		word ptr -0aH[bp],0
	jge		L$12
	mov		cx,word ptr -0aH[bp]
	neg		cx
	jcxz		L$11
L$10:
	shr		dx,1
	rcr		ax,1
	loop		L$10
L$11:
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
L$12:
	mov		cx,word ptr -0aH[bp]
	jcxz		L$14
L$13:
	shl		ax,1
	rcl		dx,1
	loop		L$13
L$14:
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
sf_gain_:
	push		bx
	push		cx
	push		0
	push		5dcH
	mov		bx,0fc7cH
	mov		cx,0ffffH
	call		near ptr sf_clip_
	neg		dx
	neg		ax
	sbb		dx,0
	mov		bx,7c9H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,64H
	xor		cx,cx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	test		dx,dx
	jg		L$15
	jne		L$16
	cmp		ax,1c20H
	jb		L$16
L$15:
	add		ax,0d120H
	adc		dx,0ffffH
	call		near ptr sf_ratio_
	add		ax,ax
	adc		dx,dx
	pop		cx
	pop		bx
	ret
L$16:
	call		near ptr sf_ratio_
	mov		cx,9
L$17:
	sar		dx,1
	rcr		ax,1
	loop		L$17
	pop		cx
	pop		bx
	ret
	cld
sf_pan_gain_:
	push		bx
	push		cx
	push		si
	push		di
	test		dx,dx
	jl		L$18
	jne		L$19
	test		ax,ax
	ja		L$19
L$18:
	xor		ax,ax
	xor		dx,dx
	jmp		L$23
L$19:
	test		dx,dx
	jg		L$20
	jne		L$21
	cmp		ax,8000H
	jb		L$21
L$20:
	mov		ax,8000H
	xor		dx,dx
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
L$21:
	mov		bx,ax
	shr		bx,7
	mov		cx,ax
	xor		ch,ah
	and		cl,7fH
	add		bx,bx
	mov		si,word ptr _sf_pan_table[bx]
	xor		di,di
	mov		ax,word ptr _sf_pan_table+2[bx]
	xor		dx,dx
	sub		ax,si
	sbb		dx,di
	mov		bx,cx
	xor		cx,cx
	call		far ptr __I4M
	mov		cx,7
L$22:
	sar		dx,1
	rcr		ax,1
	loop		L$22
	add		ax,si
	adc		dx,di
L$23:
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
	mov		ax,ax
sf_filter_coeff_:
	push		bp
	mov		bp,sp
	push		dx
	push		si
	push		di
	sub		sp,14H
	mov		di,ax
	test		cx,cx
	jg		L$24
	jne		L$26
	cmp		bx,34bcH
	jbe		L$26
L$24:
	cmp		word ptr 6[bp],1
	jne		L$25
	cmp		word ptr 4[bp],6a0aH
	jne		L$25
	mov		dword ptr [di],0
	jmp		near ptr L$29
L$25:
	mov		bx,34bcH
	jmp		L$27
L$26:
	test		cx,cx
	jge		L$27
	xor		bx,bx
L$27:
	mov		ax,bx
	xor		dx,dx
	mov		cx,32H
	div		cx
	mov		si,ax
	mov		ax,bx
	xor		dx,dx
	div		cx
	mov		cx,dx
	mov		bx,si
	shl		bx,2
	add		bx,word ptr 8[bp]
	mov		ax,word ptr [bx]
	mov		word ptr -0aH[bp],ax
	mov		ax,word ptr 2[bx]
	mov		word ptr -8[bp],ax
	test		dx,dx
	je		L$28
	mov		ax,word ptr 4[bx]
	sub		ax,word ptr -0aH[bp]
	mov		dx,word ptr 6[bx]
	sbb		dx,word ptr -8[bp]
	mov		bx,cx
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,32H
	xor		cx,cx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	add		word ptr -0aH[bp],ax
	adc		word ptr -8[bp],dx
L$28:
	mov		cx,10H
	mov		bx,word ptr -0aH[bp]
	mov		si,word ptr -8[bp]
	mov		ax,bx
	mov		dx,si
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr -1aH[bp],ax
	mov		word ptr -12H[bp],dx
	mov		bx,word ptr 4[bp]
	mov		si,word ptr 6[bp]
	mov		ax,word ptr -0aH[bp]
	mov		dx,word ptr -8[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr -18H[bp],ax
	mov		word ptr -16H[bp],dx
	mov		ax,word ptr -1aH[bp]
	add		ax,0
	mov		word ptr -14H[bp],ax
	mov		ax,word ptr -12H[bp]
	adc		ax,1
	mov		word ptr -10H[bp],ax
	mov		ax,word ptr -14H[bp]
	add		ax,word ptr -18H[bp]
	mov		word ptr -0eH[bp],ax
	mov		ax,word ptr -10H[bp]
	adc		ax,dx
	mov		word ptr -0cH[bp],ax
	mov		bx,word ptr -0eH[bp]
	mov		cx,ax
	mov		ax,word ptr -1aH[bp]
	mov		dx,word ptr -12H[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	shld		edx,eax,1cH
	shl		eax,1cH
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	mov		word ptr [di],ax
	mov		word ptr 2[di],dx
	mov		ax,word ptr -1aH[bp]
	add		ax,0
	mov		dx,word ptr -12H[bp]
	adc		dx,0ffffH
	add		ax,ax
	adc		dx,dx
	mov		cx,word ptr -0cH[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	shld		edx,eax,1cH
	shl		eax,1cH
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	mov		word ptr 4[di],ax
	mov		word ptr 6[di],dx
	mov		ax,word ptr -14H[bp]
	sub		ax,word ptr -18H[bp]
	mov		dx,word ptr -10H[bp]
	sbb		dx,word ptr -16H[bp]
	mov		cx,word ptr -0cH[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	shld		edx,eax,1cH
	shl		eax,1cH
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	mov		word ptr 8[di],ax
	mov		word ptr 0aH[di],dx
L$29:
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		dx
	pop		bp
	ret		6
sf_key_time_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	mov		si,bx
	test		cx,cx
	je		L$32
	mov		ax,3cH
	sub		ax,word ptr 4[bp]
	cwd
	mov		bx,ax
	mov		di,dx
	mov		ax,cx
	cwd
	mov		cx,di
	call		far ptr __I4M
	mov		cx,ax
	mov		bx,dx
	mov		ax,si
	cwd
	add		ax,cx
	adc		dx,bx
	cmp		dx,0ffffH
	jl		L$30
	jne		L$31
	cmp		ax,0d8f0H
	jae		L$31
L$30:
	xor		ax,ax
	xor		dx,dx
	jmp		L$32
L$31:
	mov		bx,word ptr _sf_rate
	call		near ptr sf_ratio_
	mov		cx,18H
	xor		si,si
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
L$32:
	pop		di
	pop		si
	pop		bp
	ret		2
sf_env_start_:
	push		si
	mov		si,ax
	mov		byte ptr 0eH[si],dl
	mov		word ptr [si],bx
	mov		word ptr 2[si],cx
	mov		dword ptr 4[si],0
	mov		ax,cx
	or		ax,bx
	je		L$33
	xor		ax,ax
	mov		dx,100H
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	jmp		L$34
L$33:
	xor		dx,dx
L$34:
	mov		word ptr 8[si],ax
	mov		word ptr 0aH[si],dx
	pop		si
	ret
	cld
L$35:
    DW	offset L$37
    DW	offset L$39
    DW	offset L$40
    DW	offset L$44
	mov		ax,ax
sf_env_next_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,6
	mov		word ptr -8[bp],ax
	mov		di,bx
	mov		word ptr -6[bp],cx
	mov		word ptr -0aH[bp],dx
L$36:
	mov		bx,word ptr -8[bp]
	mov		al,byte ptr 0eH[bx]
	cmp		al,3
	ja		L$45
	xor		ah,ah
	mov		bx,ax
	add		bx,ax
	jmp		word ptr cs:L$35[bx]
L$37:
	mov		es,word ptr -6[bp]
	mov		bx,word ptr es:4[di]
	mov		cx,word ptr es:6[di]
	mov		dx,1
	mov		ax,word ptr -8[bp]
	call		near ptr sf_env_start_
L$38:
	mov		bx,word ptr -8[bp]
	mov		ax,word ptr 2[bx]
	or		ax,word ptr [bx]
	je		L$36
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		2
L$39:
	push		word ptr -0aH[bp]
	mov		es,word ptr -6[bp]
	mov		cx,word ptr es:14H[di]
	mov		bx,word ptr es:18H[di]
	mov		ax,word ptr es:8[di]
	mov		dx,word ptr es:0aH[di]
	call		near ptr sf_key_time_
	mov		bx,ax
	mov		cx,dx
	mov		dx,2
	mov		ax,word ptr -8[bp]
	call		near ptr sf_env_start_
	jmp		L$38
L$40:
	push		word ptr -0aH[bp]
	mov		es,word ptr -6[bp]
	mov		cx,word ptr es:16H[di]
	mov		bx,word ptr es:1aH[di]
	mov		ax,word ptr es:0cH[di]
	mov		dx,word ptr es:0eH[di]
	call		near ptr sf_key_time_
	cmp		word ptr 4[bp],0
	je		L$41
	mov		es,word ptr -6[bp]
	mov		bx,word ptr es:20H[di]
	mov		si,word ptr es:22H[di]
	mov		cx,0fH
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	jmp		L$42
L$41:
	mov		es,word ptr -6[bp]
	mov		bx,word ptr es:1cH[di]
	xor		si,si
	mov		cx,8000H
	sub		cx,bx
	mov		bx,cx
	mov		cx,si
	sbb		cx,si
	mov		si,cx
	mov		cx,0fH
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
L$42:
	mov		bx,ax
	mov		cx,dx
	cmp		cx,0ffH
	jbe		L$43
	mov		bx,0ffffH
	mov		cx,0ffH
L$43:
	mov		dx,3
	mov		ax,word ptr -8[bp]
	call		near ptr sf_env_start_
	jmp		near ptr L$38
L$44:
	xor		bx,bx
	xor		cx,cx
	mov		dx,4
	mov		ax,word ptr -8[bp]
	call		near ptr sf_env_start_
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		2
L$45:
	xor		bx,bx
	xor		cx,cx
	mov		dx,6
	mov		ax,word ptr -8[bp]
	call		near ptr sf_env_start_
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		2
	cld
L$46:
    DW	offset L$47
    DW	offset L$49
    DW	offset L$50
    DW	offset L$52
    DW	offset L$53
	mov		ax,ax
sf_env_level_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,4
	mov		si,ax
	mov		word ptr -6[bp],bx
	mov		es,cx
	mov		ax,dx
	mov		di,word ptr 4[si]
	mov		dx,word ptr 6[si]
	mov		cl,9
	shr		di,cl
	ror		dx,cl
	xor		di,dx
	and		dx,7fH
	xor		di,dx
	mov		word ptr -8[bp],dx
	mov		bl,byte ptr 0eH[si]
	dec		bl
	cmp		bl,4
	ja		L$56
	xor		bh,bh
	add		bx,bx
	jmp		word ptr cs:L$46[bx]
L$47:
	test		ax,ax
	je		L$48
	mov		ax,di
	jmp		near ptr L$57
L$48:
	mov		ax,8000H
	sub		ax,di
	mov		dx,0
	sbb		dx,word ptr -8[bp]
	mov		word ptr -8[bp],dx
	mov		cx,0fH
	mov		bx,ax
	mov		si,dx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		bx,8000H
	sub		bx,ax
	mov		ax,bx
	mov		bx,0
	sbb		bx,dx
	mov		dx,bx
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$49:
	mov		ax,8000H
	xor		dx,dx
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$50:
	test		ax,ax
	je		L$51
	mov		bx,word ptr -6[bp]
	mov		bx,word ptr es:1eH[bx]
	mov		cx,0fH
	xor		si,si
	mov		ax,di
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	call		near ptr sf_gain_
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$51:
	mov		bx,word ptr -6[bp]
	mov		bx,word ptr es:1cH[bx]
	xor		si,si
	mov		ax,8000H
	sub		ax,bx
	mov		bx,ax
	mov		ax,si
	sbb		ax,si
	mov		si,ax
	mov		cx,0fH
	mov		ax,di
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		bx,8000H
	sub		bx,ax
	mov		ax,bx
	mov		bx,0
	sbb		bx,dx
	mov		dx,bx
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$52:
	mov		bx,word ptr -6[bp]
	mov		ax,word ptr es:1cH[bx]
	xor		dx,dx
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$53:
	test		ax,ax
	je		L$55
	mov		ax,di
	mov		bx,322H
	xor		cx,cx
	call		far ptr __I4M
	mov		di,ax
	mov		cx,0fH
L$54:
	sar		dx,1
	rcr		di,1
	loop		L$54
	mov		ax,di
	call		near ptr sf_gain_
	mov		di,word ptr 0cH[si]
	mov		cx,0fH
	mov		bx,ax
	mov		si,dx
	mov		ax,di
	xor		dx,dx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$55:
	mov		bx,8000H
	sub		bx,di
	sbb		ax,dx
	mov		dx,word ptr 0cH[si]
	mov		cx,0fH
	mov		si,ax
	mov		ax,dx
	xor		dx,dx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
L$56:
	xor		ax,ax
	xor		dx,dx
L$57:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret
	cld
sf_env_advance_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,6
	mov		si,ax
	mov		word ptr -8[bp],bx
	mov		word ptr -6[bp],cx
	mov		di,dx
	mov		ax,word ptr 2[si]
	or		ax,word ptr [si]
	je		L$58
	mov		word ptr -0aH[bp],0
	mov		ax,word ptr 8[si]
	mov		dx,word ptr 0aH[si]
	mov		bx,di
	xor		cx,cx
	call		far ptr __U4M
	add		word ptr 4[si],ax
	adc		word ptr 6[si],dx
	sub		word ptr [si],di
	mov		ax,word ptr -0aH[bp]
	sbb		word ptr 2[si],ax
	mov		di,word ptr 2[si]
	or		di,word ptr [si]
	jne		L$58
	push		word ptr 6[bp]
	mov		dx,word ptr 4[bp]
	mov		bx,word ptr -8[bp]
	mov		cx,word ptr -6[bp]
	mov		ax,si
	call		near ptr sf_env_next_
L$58:
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		4
sf_release_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,4
	mov		si,ax
	mov		word ptr -0cH[bp],dx
	mov		di,word ptr [si]
	mov		ax,word ptr 2[si]
	mov		word ptr -0aH[bp],ax
	cmp		byte ptr 4eH[si],5
	jb		L$59
	test		dx,dx
	je		L$65
	cmp		byte ptr 75H[si],0
	jne		L$65
L$59:
	mov		byte ptr 74H[si],0
	mov		al,byte ptr -0cH[bp]
	mov		byte ptr 75H[si],al
	lea		bx,10H[di]
	lea		ax,40H[si]
	mov		dx,1
	mov		cx,word ptr -0aH[bp]
	call		near ptr sf_env_level_
	mov		word ptr 4cH[si],ax
	test		ax,ax
	jne		L$60
	mov		word ptr [si],ax
	mov		word ptr 2[si],ax
	jmp		L$65
L$60:
	lea		bx,34H[di]
	lea		ax,50H[si]
	xor		dx,dx
	mov		cx,word ptr -0aH[bp]
	call		near ptr sf_env_level_
	mov		word ptr 5cH[si],ax
	cmp		word ptr -0cH[bp],0
	je		L$61
	mov		bx,word ptr _sf_quick_release
	xor		cx,cx
	jmp		L$62
L$61:
	mov		es,word ptr -0aH[bp]
	mov		bx,word ptr es:20H[di]
	mov		cx,word ptr es:22H[di]
L$62:
	lea		ax,40H[si]
	mov		dx,5
	call		near ptr sf_env_start_
	cmp		word ptr -0cH[bp],0
	je		L$63
	mov		bx,word ptr _sf_quick_release
	xor		cx,cx
	jmp		L$64
L$63:
	mov		es,word ptr -0aH[bp]
	mov		bx,word ptr es:44H[di]
	mov		cx,word ptr es:46H[di]
L$64:
	lea		ax,50H[si]
	mov		dx,5
	call		near ptr sf_env_start_
	mov		es,word ptr -0aH[bp]
	cmp		byte ptr es:96H[di],2
	jne		L$65
	mov		dword ptr 14H[si],0
L$65:
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
	cld
sf_lfo_level_:
	push		bx
	push		cx
	mov		bx,ax
	mov		ax,word ptr [bx]
	mov		dx,word ptr 2[bx]
	cmp		dx,40H
	jae		L$66
	mov		cl,7
	shr		ax,cl
	ror		dx,cl
	xor		ax,dx
	and		dx,1ffH
	xor		ax,dx
	pop		cx
	pop		bx
	ret
L$66:
	cmp		dx,0c0H
	jae		L$67
	xor		bx,bx
	sub		bx,ax
	mov		ax,bx
	mov		bx,80H
	sbb		bx,dx
	mov		dx,bx
	jmp		L$68
L$67:
	add		ax,0
	adc		dx,0ff00H
L$68:
	mov		cx,7
L$69:
	sar		dx,1
	rcr		ax,1
	loop		L$69
	pop		cx
	pop		bx
	ret
	cld
sf_lfo_advance_:
	push		si
	mov		si,ax
	mov		ax,bx
	mov		bx,dx
	xor		dx,dx
	cmp		word ptr 6[si],0
	ja		L$70
	jne		L$71
	cmp		bx,word ptr 4[si]
	ja		L$71
L$70:
	sub		word ptr 4[si],bx
	sbb		word ptr 6[si],dx
	pop		si
	ret
L$71:
	sub		bx,word ptr 4[si]
	mov		word ptr 4[si],dx
	mov		word ptr 6[si],dx
	mov		dx,cx
	xor		cx,cx
	call		far ptr __U4M
	add		ax,word ptr [si]
	adc		dx,word ptr 2[si]
	mov		word ptr [si],ax
	xor		dh,dh
	mov		word ptr 2[si],dx
	pop		si
	ret
	mov		ax,ax
sf_find_preset_:
	push		bx
	push		cx
	push		si
	push		di
	push		bp
	mov		bp,sp
	sub		sp,2
	mov		si,ax
	mov		word ptr -2[bp],dx
	xor		ax,ax
	mov		cx,word ptr _sf_bank+0cH
	les		di,dword ptr _sf_bank
L$72:
	cmp		ax,cx
	jae		L$75
	mov		dx,cx
	sub		dx,ax
	shr		dx,1
	add		dx,ax
	imul		bx,dx,0aH
	add		bx,di
	cmp		si,word ptr es:6[bx]
	ja		L$73
	jne		L$74
	mov		bx,word ptr es:8[bx]
	cmp		bx,word ptr -2[bp]
	jae		L$74
L$73:
	mov		ax,dx
	inc		ax
	jmp		L$72
L$74:
	mov		cx,dx
	jmp		L$72
L$75:
	cmp		ax,word ptr _sf_bank+0cH
	jne		L$76
	mov		dx,0ffffH
	jmp		L$79
L$76:
	imul		dx,ax,0aH
	les		bx,dword ptr _sf_bank
	add		bx,dx
	cmp		si,word ptr es:6[bx]
	jne		L$77
	mov		dx,word ptr es:8[bx]
	cmp		dx,word ptr -2[bp]
	je		L$78
L$77:
	mov		ax,0ffffH
L$78:
	mov		dx,ax
L$79:
	mov		ax,dx
	leave
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
sf_uses_drum_bank_msb_:
	push		bx
	mov		bx,ax
	cmp		byte ptr 1dH[bx],0
	je		L$81
	mov		ax,word ptr _sf_mode
	cmp		ax,2
	je		L$80
	cmp		ax,3
	jne		L$81
L$80:
	mov		ax,1
	pop		bx
	ret
L$81:
	xor		ax,ax
	pop		bx
	ret
	cld
sf_select_preset_:
	push		bx
	push		cx
	push		dx
	push		si
	mov		bx,ax
	mov		si,word ptr 18H[bx]
	movzx		cx,byte ptr 1cH[bx]
	mov		ax,0ffffH
	cmp		byte ptr 1dH[bx],0
	je		L$84
	mov		ax,bx
	call		near ptr sf_uses_drum_bank_msb_
	test		ax,ax
	je		L$82
	xor		si,si
L$82:
	mov		ax,si
	or		al,80H
	mov		dx,cx
	call		near ptr sf_find_preset_
	cmp		ax,0ffffH
	jne		L$83
	test		si,si
	je		L$83
	mov		dx,cx
	mov		ax,80H
	call		near ptr sf_find_preset_
L$83:
	cmp		ax,0ffffH
	jne		L$84
	xor		dx,dx
	mov		ax,80H
	call		near ptr sf_find_preset_
L$84:
	cmp		ax,0ffffH
	jne		L$85
	test		si,si
	je		L$85
	cmp		si,80H
	je		L$85
	mov		dx,cx
	mov		ax,si
	call		near ptr sf_find_preset_
L$85:
	cmp		ax,0ffffH
	jne		L$86
	mov		dx,cx
	xor		ax,ax
	call		near ptr sf_find_preset_
L$86:
	cmp		ax,0ffffH
	jne		L$87
	xor		dx,dx
	xor		ax,ax
	call		near ptr sf_find_preset_
L$87:
	cmp		ax,0ffffH
	jne		L$88
	xor		ax,ax
L$88:
	mov		word ptr [bx],ax
	pop		si
	pop		dx
	pop		cx
	pop		bx
	ret
sf_program_:
	push		bx
	imul		ax,2aH
	mov		bx,offset _sf_channels
	add		bx,ax
	mov		byte ptr 1cH[bx],dl
	mov		ax,bx
	call		near ptr sf_uses_drum_bank_msb_
	test		ax,ax
	jne		L$89
	mov		ax,word ptr 2[bx]
	and		ah,7fH
	mov		word ptr 18H[bx],ax
L$89:
	mov		ax,bx
	call		near ptr sf_select_preset_
	pop		bx
	ret
	mov		ax,ax
	cld
sf_set_drum_:
	push		bx
	mov		bx,ax
	movzx		ax,byte ptr 1dH[bx]
	cmp		ax,dx
	je		L$90
	mov		byte ptr 1dH[bx],dl
	mov		ax,bx
	call		near ptr sf_select_preset_
L$90:
	pop		bx
	ret
	mov		ax,ax
	cld
sf_pitch_channel_:
	push		bx
	push		cx
	push		dx
	push		si
	push		di
	push		bp
	mov		bp,sp
	sub		sp,6
	mov		si,ax
	mov		di,word ptr 4[si]
	xor		ax,ax
	add		di,0e000H
	adc		ax,0ffffH
	mov		word ptr -2[bp],ax
	mov		ax,word ptr 16H[si]
	cwd
	mov		bx,ax
	mov		cx,dx
	mov		ax,di
	mov		dx,word ptr -2[bp]
	call		far ptr __I4M
	mov		word ptr -6[bp],ax
	mov		word ptr -4[bp],dx
	mov		cx,0dH
L$91:
	sar		word ptr -4[bp],1
	rcr		word ptr -6[bp],1
	loop		L$91
	mov		ax,word ptr -4[bp]
	mov		word ptr -2[bp],ax
	mov		ax,word ptr 12H[si]
	cwd
	mov		bx,64H
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr 14H[si]
	cwd
	add		ax,bx
	adc		dx,cx
	mov		bx,word ptr -6[bp]
	add		bx,ax
	mov		word ptr 1eH[si],bx
	mov		ax,word ptr -2[bp]
	adc		ax,dx
	mov		word ptr 20H[si],ax
	leave
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		bx
	ret
	mov		ax,ax
sf_gain_channel_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		dx
	push		si
	push		di
	sub		sp,2
	mov		word ptr -0cH[bp],ax
	mov		bx,ax
	mov		ax,word ptr 8[bx]
	inc		ax
	mov		bx,word ptr 0aH[bx]
	inc		bx
	xor		dx,dx
	xor		cx,cx
	call		far ptr __I4M
	mov		di,ax
	mov		cx,0dH
L$92:
	sar		dx,1
	rcr		di,1
	loop		L$92
	mov		cx,0fH
	mov		bx,di
	mov		si,dx
	mov		ax,di
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		bx,word ptr -0cH[bp]
	mov		word ptr 22H[bx],ax
	mov		word ptr 24H[bx],dx
	lea		sp,-0aH[bp]
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		bx
	pop		bp
	ret
	mov		ax,ax
	cld
sf_vibrato_channel_:
	push		bx
	push		cx
	push		dx
	push		si
	push		di
	push		bp
	mov		bp,sp
	sub		sp,2
	mov		word ptr -2[bp],ax
	mov		bx,ax
	mov		ax,word ptr 0cH[bx]
	xor		dx,dx
	mov		bx,32H
	xor		cx,cx
	call		far ptr __I4M
	mov		si,ax
	mov		di,dx
	mov		cx,0eH
L$93:
	sar		di,1
	rcr		si,1
	loop		L$93
	mov		bx,word ptr -2[bp]
	movzx		ax,byte ptr 1bH[bx]
	xor		dx,dx
	mov		bx,32H
	xor		cx,cx
	call		far ptr __I4M
	mov		cx,7
L$94:
	sar		dx,1
	rcr		ax,1
	loop		L$94
	add		si,ax
	mov		bx,word ptr -2[bp]
	mov		word ptr 26H[bx],si
	adc		di,dx
	mov		word ptr 28H[bx],di
	leave
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		bx
	ret
sf_stop_playback_:
	push		bx
	xor		ax,ax
L$95:
	cmp		ax,word ptr _sf_limit
	jae		L$96
	imul		bx,ax,76H
	mov		dword ptr _sf_voices[bx],0
	inc		ax
	jmp		L$95
L$96:
	xor		ax,ax
L$97:
	imul		bx,ax,2aH
	mov		byte ptr _sf_channels+1aH[bx],0
	inc		ax
	cmp		ax,10H
	jb		L$97
	xor		ax,ax
	mov		word ptr _sf_serial,ax
	mov		word ptr _sf_serial+2,ax
	pop		bx
	ret
	mov		ax,ax
sf_reset_:
	push		bx
	push		cx
	push		dx
	mov		dx,ax
	call		near ptr sf_stop_playback_
	mov		word ptr _sf_mode,dx
	mov		ax,word ptr _sf_headroom_gain
	mov		word ptr _sf_output_gain,ax
	xor		cx,cx
L$98:
	imul		bx,cx,2aH
	add		bx,offset _sf_channels
	mov		byte ptr 1bH[bx],0
	mov		al,byte ptr 1bH[bx]
	xor		ah,ah
	mov		word ptr 10H[bx],ax
	mov		word ptr 0cH[bx],ax
	mov		word ptr 18H[bx],ax
	mov		word ptr 2[bx],ax
	mov		word ptr 6[bx],2000H
	mov		ax,word ptr 6[bx]
	mov		word ptr 4[bx],ax
	mov		word ptr 0aH[bx],3fffH
	mov		ax,word ptr 0aH[bx]
	mov		word ptr 8[bx],ax
	mov		word ptr 0eH[bx],0ffffH
	mov		dword ptr 14H[bx],0c80000H
	mov		ax,word ptr 14H[bx]
	mov		word ptr 12H[bx],ax
	mov		dword ptr 26H[bx],0
	mov		ax,word ptr 26H[bx]
	mov		dx,word ptr 28H[bx]
	mov		word ptr 1eH[bx],ax
	mov		word ptr 20H[bx],dx
	mov		dword ptr 22H[bx],8000H
	cmp		cx,9
	sete		al
	mov		byte ptr 1dH[bx],al
	xor		dx,dx
	mov		ax,cx
	call		near ptr sf_program_
	inc		cx
	cmp		cx,10H
	jb		L$98
	pop		dx
	pop		cx
	pop		bx
	ret
	cld
sf_note_on_:
	push		bp
	mov		bp,sp
	push		cx
	push		si
	push		di
	sub		sp,22H
	mov		word ptr -18H[bp],ax
	mov		word ptr -1cH[bp],dx
	mov		word ptr -24H[bp],bx
	imul		bx,ax,2aH
	mov		ax,word ptr _sf_channels[bx]
	mov		word ptr -1aH[bp],ax
	imul		ax,0aH
	mov		bx,word ptr _sf_bank
	mov		dx,word ptr _sf_bank+2
	mov		word ptr -20H[bp],dx
	add		bx,ax
	mov		word ptr -22H[bp],bx
	add		word ptr _sf_serial,1
	adc		word ptr _sf_serial+2,0
	mov		ax,word ptr _sf_serial
	mov		word ptr -12H[bp],ax
	mov		ax,word ptr _sf_serial+2
	mov		word ptr -10H[bp],ax
	mov		si,word ptr -24H[bp]
	xor		dx,dx
	mov		cl,0fH
	shl		dx,cl
	rol		si,cl
	xor		dx,si
	and		si,8000H
	xor		dx,si
	mov		bx,7fH
	xor		cx,cx
	mov		ax,si
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	mov		cx,0fH
	mov		bx,ax
	mov		si,dx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr -28H[bp],ax
	mov		word ptr -26H[bp],dx
	mov		word ptr -1eH[bp],0
L$99:
	mov		ax,word ptr -1eH[bp]
	les		bx,dword ptr -22H[bp]
	cmp		ax,word ptr es:4[bx]
	jae		L$119
	imul		dx,ax,98H
	mov		bx,word ptr es:[bx]
	mov		si,word ptr -22H[bp]
	mov		ax,word ptr es:2[si]
	mov		word ptr -8[bp],ax
	add		bx,dx
	mov		word ptr -0aH[bp],bx
	mov		es,ax
	movzx		ax,byte ptr es:92H[bx]
	cmp		ax,word ptr -1cH[bp]
	ja		L$118
	movzx		ax,byte ptr es:93H[bx]
	cmp		ax,word ptr -1cH[bp]
	jb		L$118
	movzx		ax,byte ptr es:94H[bx]
	cmp		ax,word ptr -24H[bp]
	ja		L$118
	movzx		ax,byte ptr es:95H[bx]
	cmp		ax,word ptr -24H[bp]
	jb		L$118
	xor		ax,ax
	mov		word ptr -0eH[bp],ax
	xor		di,di
	mov		word ptr -14H[bp],ax
	mov		word ptr -0cH[bp],ax
	xor		cx,cx
L$100:
	cmp		cx,word ptr _sf_limit
	jae		L$109
	imul		bx,cx,76H
	add		bx,offset _sf_voices
	mov		dx,word ptr [bx]
	mov		ax,word ptr 2[bx]
	test		ax,ax
	jne		L$101
	test		dx,dx
	jne		L$101
	test		di,di
	jne		L$108
	mov		di,bx
	jmp		near ptr L$108
L$101:
	les		si,dword ptr -0aH[bp]
	cmp		word ptr es:8eH[si],0
	je		L$103
	mov		es,ax
	mov		si,dx
	mov		ax,word ptr es:8eH[si]
	les		si,dword ptr -0aH[bp]
	cmp		ax,word ptr es:8eH[si]
	jne		L$103
	movzx		ax,byte ptr 72H[bx]
	cmp		ax,word ptr -18H[bp]
	jne		L$103
	mov		ax,word ptr 70H[bx]
	cmp		ax,word ptr -1aH[bp]
	jne		L$103
	mov		ax,word ptr 12H[bx]
	cmp		ax,word ptr -10H[bp]
	jne		L$102
	mov		ax,word ptr 10H[bx]
	cmp		ax,word ptr -12H[bp]
	je		L$103
L$102:
	mov		dx,1
	mov		ax,bx
	call		near ptr sf_release_
L$103:
	mov		si,word ptr [bx]
	mov		ax,word ptr 2[bx]
	test		ax,ax
	jne		L$104
	test		si,si
	jne		L$104
	test		di,di
	jne		L$108
	mov		di,bx
	inc		cx
	jmp		near ptr L$100
L$104:
	cmp		byte ptr 4eH[bx],5
	jne		L$108
	cmp		byte ptr 75H[bx],0
	je		L$105
	mov		ax,word ptr _sf_quick_release
	xor		si,si
	jmp		L$106
L$105:
	mov		es,ax
	mov		ax,word ptr es:20H[si]
	mov		si,word ptr es:22H[si]
L$106:
	sub		ax,word ptr 40H[bx]
	sbb		si,word ptr 42H[bx]
	cmp		word ptr -0eH[bp],0
	je		L$107
	cmp		si,word ptr -0cH[bp]
	ja		L$107
	jne		L$108
	cmp		ax,word ptr -14H[bp]
	jbe		L$108
L$107:
	mov		word ptr -0eH[bp],bx
	mov		word ptr -14H[bp],ax
	mov		word ptr -0cH[bp],si
L$108:
	inc		cx
	jmp		near ptr L$100
L$109:
	test		di,di
	jne		L$110
	mov		di,word ptr -0eH[bp]
L$110:
	test		di,di
	jne		L$115
	xor		ax,ax
	mov		word ptr -16H[bp],di
	xor		cx,cx
L$111:
	cmp		cx,word ptr _sf_limit
	jae		L$114
	imul		bx,cx,76H
	add		bx,offset _sf_voices
	cmp		byte ptr 74H[bx],0
	je		L$113
	mov		dx,word ptr -12H[bp]
	sub		dx,word ptr 10H[bx]
	mov		si,word ptr -10H[bp]
	sbb		si,word ptr 12H[bx]
	cmp		si,ax
	ja		L$112
	jne		L$113
	cmp		dx,word ptr -16H[bp]
	jbe		L$113
L$112:
	mov		word ptr -16H[bp],dx
	mov		ax,si
	mov		di,bx
L$113:
	inc		cx
	jmp		L$111
L$114:
	test		di,di
	je		L$118
L$115:
	mov		bx,word ptr -0aH[bp]
	mov		word ptr [di],bx
	mov		ax,word ptr -8[bp]
	mov		word ptr 2[di],ax
	mov		al,byte ptr -18H[bp]
	mov		byte ptr 72H[di],al
	mov		al,byte ptr -1cH[bp]
	mov		byte ptr 73H[di],al
	mov		ax,word ptr -12H[bp]
	mov		word ptr 10H[di],ax
	mov		ax,word ptr -10H[bp]
	mov		word ptr 12H[di],ax
	mov		byte ptr 75H[di],0
	mov		al,byte ptr 75H[di]
	mov		byte ptr 74H[di],al
	mov		ax,word ptr -1aH[bp]
	mov		word ptr 70H[di],ax
	mov		es,word ptr -8[bp]
	mov		dx,word ptr es:[bx]
	mov		ax,word ptr es:2[bx]
	mov		word ptr 4[di],dx
	mov		word ptr 6[di],ax
	mov		dword ptr 8[di],0
	mov		dx,word ptr es:0cH[bx]
	mov		ax,word ptr es:0eH[bx]
	mov		word ptr 14H[di],dx
	mov		word ptr 16H[di],ax
	mov		ax,word ptr es:7aH[bx]
	cwd
	mov		bx,word ptr -1cH[bp]
	xor		cx,cx
	call		far ptr __I4M
	mov		bx,ax
	mov		cx,dx
	mov		si,word ptr -0aH[bp]
	mov		ax,word ptr es:78H[si]
	cwd
	add		ax,bx
	mov		word ptr 18H[di],ax
	adc		dx,cx
	mov		word ptr 1aH[di],dx
	mov		dword ptr 1cH[di],7fffffffH
	mov		ax,word ptr -28H[bp]
	mov		word ptr 24H[di],ax
	mov		ax,word ptr -26H[bp]
	mov		word ptr 26H[di],ax
	mov		bx,si
	mov		ax,word ptr es:7eH[bx]
	cwd
	call		near ptr sf_gain_
	mov		si,dx
	mov		cx,0fH
	mov		bx,ax
	mov		ax,word ptr -28H[bp]
	mov		dx,word ptr -26H[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr 20H[di],ax
	mov		word ptr 22H[di],dx
	les		bx,dword ptr -0aH[bp]
	mov		ax,word ptr es:68H[bx]
	mov		dx,word ptr es:6aH[bx]
	mov		word ptr 34H[di],ax
	mov		word ptr 36H[di],dx
	mov		ax,word ptr es:6cH[bx]
	mov		dx,word ptr es:6eH[bx]
	mov		word ptr 38H[di],ax
	mov		word ptr 3aH[di],dx
	mov		dx,word ptr es:70H[bx]
	mov		ax,word ptr es:72H[bx]
	mov		word ptr 3cH[di],dx
	mov		word ptr 3eH[di],ax
	mov		ax,word ptr es:80H[bx]
	cwd
	mov		word ptr 28H[di],ax
	mov		word ptr 2aH[di],dx
	mov		dword ptr 30H[di],0
	mov		dx,word ptr 30H[di]
	mov		ax,word ptr 32H[di]
	mov		word ptr 2cH[di],dx
	mov		word ptr 2eH[di],ax
	mov		bx,word ptr es:10H[bx]
	mov		si,word ptr -0aH[bp]
	mov		cx,word ptr es:12H[si]
	lea		si,40H[di]
	xor		dx,dx
	mov		ax,si
	call		near ptr sf_env_start_
	les		bx,dword ptr -0aH[bp]
	mov		dx,word ptr es:34H[bx]
	mov		cx,word ptr es:36H[bx]
	lea		ax,50H[di]
	mov		bx,dx
	xor		dx,dx
	call		near ptr sf_env_start_
	mov		ax,word ptr 42H[di]
	or		ax,word ptr 40H[di]
	jne		L$116
	push		1
	mov		bx,word ptr -0aH[bp]
	add		bx,10H
	mov		dx,word ptr -1cH[bp]
	mov		cx,word ptr -8[bp]
	mov		ax,si
	call		near ptr sf_env_next_
L$116:
	mov		ax,word ptr 52H[di]
	or		ax,word ptr 50H[di]
	jne		L$117
	push		ax
	mov		bx,word ptr -0aH[bp]
	add		bx,34H
	lea		ax,50H[di]
	mov		dx,word ptr -1cH[bp]
	mov		cx,word ptr -8[bp]
	call		near ptr sf_env_next_
L$117:
	les		bx,dword ptr -0aH[bp]
	mov		dx,word ptr es:58H[bx]
	mov		ax,word ptr es:5aH[bx]
	mov		word ptr 64H[di],dx
	mov		word ptr 66H[di],ax
	mov		ax,word ptr es:5cH[bx]
	mov		dx,word ptr es:5eH[bx]
	mov		word ptr 6cH[di],ax
	mov		word ptr 6eH[di],dx
	mov		dword ptr 68H[di],0
	mov		ax,word ptr 68H[di]
	mov		dx,word ptr 6aH[di]
	mov		word ptr 60H[di],ax
	mov		word ptr 62H[di],dx
L$118:
	inc		word ptr -1eH[bp]
	jmp		near ptr L$99
L$119:
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
	cld
sf_note_off_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,6
	mov		word ptr -0aH[bp],ax
	mov		word ptr -0eH[bp],dx
	mov		word ptr -0cH[bp],0
	xor		si,si
	xor		di,di
	xor		cx,cx
L$120:
	cmp		cx,word ptr _sf_limit
	jae		L$124
	imul		bx,cx,76H
	add		bx,offset _sf_voices
	mov		dx,word ptr [bx]
	mov		ax,word ptr 2[bx]
	test		ax,ax
	jne		L$121
	test		dx,dx
	je		L$123
L$121:
	movzx		ax,byte ptr 72H[bx]
	cmp		ax,word ptr -0aH[bp]
	jne		L$123
	movzx		ax,byte ptr 73H[bx]
	cmp		ax,word ptr -0eH[bp]
	jne		L$123
	cmp		byte ptr 4eH[bx],5
	jae		L$123
	cmp		byte ptr 74H[bx],0
	jne		L$123
	test		di,di
	je		L$122
	mov		dx,word ptr _sf_serial
	mov		ax,word ptr _sf_serial+2
	sub		dx,word ptr 10H[bx]
	sbb		ax,word ptr 12H[bx]
	cmp		ax,si
	ja		L$122
	jne		L$123
	cmp		dx,word ptr -0cH[bp]
	jbe		L$123
L$122:
	mov		ax,word ptr _sf_serial
	mov		si,word ptr _sf_serial+2
	sub		ax,word ptr 10H[bx]
	sbb		si,word ptr 12H[bx]
	mov		word ptr -0cH[bp],ax
	mov		di,1
L$123:
	inc		cx
	jmp		L$120
L$124:
	test		di,di
	je		L$65
	xor		cx,cx
	imul		di,word ptr -0aH[bp],2aH
L$125:
	cmp		cx,word ptr _sf_limit
	jae		L$65
	imul		bx,cx,76H
	add		bx,offset _sf_voices
	mov		dx,word ptr [bx]
	mov		ax,word ptr 2[bx]
	test		ax,ax
	jne		L$126
	test		dx,dx
	je		L$128
L$126:
	movzx		ax,byte ptr 72H[bx]
	cmp		ax,word ptr -0aH[bp]
	jne		L$128
	movzx		ax,byte ptr 73H[bx]
	cmp		ax,word ptr -0eH[bp]
	jne		L$128
	mov		dx,word ptr _sf_serial
	mov		ax,word ptr _sf_serial+2
	sub		dx,word ptr 10H[bx]
	sbb		ax,word ptr 12H[bx]
	cmp		ax,si
	jne		L$128
	cmp		dx,word ptr -0cH[bp]
	jne		L$128
	cmp		byte ptr _sf_channels+1aH[di],0
	je		L$127
	mov		byte ptr 74H[bx],1
	jmp		L$128
L$127:
	xor		dx,dx
	mov		ax,bx
	call		near ptr sf_release_
L$128:
	inc		cx
	jmp		L$125
sf_release_channel_:
	push		bp
	mov		bp,sp
	push		cx
	push		si
	push		di
	sub		sp,2
	mov		di,ax
	mov		word ptr -8[bp],dx
	mov		si,bx
	xor		cx,cx
L$129:
	cmp		cx,word ptr _sf_limit
	jae		L$119
	imul		bx,cx,76H
	add		bx,offset _sf_voices
	mov		dx,word ptr [bx]
	mov		ax,word ptr 2[bx]
	test		ax,ax
	jne		L$130
	test		dx,dx
	je		L$132
L$130:
	movzx		ax,byte ptr 72H[bx]
	cmp		ax,di
	jne		L$132
	cmp		word ptr -8[bp],0
	je		L$131
	cmp		byte ptr 74H[bx],0
	je		L$132
L$131:
	mov		dx,si
	mov		ax,bx
	call		near ptr sf_release_
L$132:
	inc		cx
	jmp		L$129
sf_control_:
	push		bp
	mov		bp,sp
	push		cx
	push		si
	push		di
	sub		sp,2
	mov		word ptr -8[bp],ax
	mov		ax,dx
	mov		di,bx
	imul		si,word ptr -8[bp],2aH
	add		si,offset _sf_channels
	cmp		dx,27H
	jb		L$136
	jbe		L$150
	cmp		dx,64H
	jb		L$134
	jbe		L$159
	cmp		dx,78H
	jb		L$133
	jbe		L$169
	cmp		dx,79H
	jbe		L$171
	cmp		dx,7bH
	jb		L$174
	cmp		dx,7dH
	jbe		L$170
	jmp		near ptr L$174
L$133:
	cmp		dx,65H
	je		L$157
	jmp		near ptr L$174
L$134:
	cmp		dx,2bH
	jb		L$135
	jbe		L$152
	cmp		dx,40H
	jb		L$174
	jbe		L$155
	cmp		dx,62H
	jb		L$174
	jmp		near ptr L$161
L$135:
	cmp		dx,2aH
	je		L$154
	jmp		near ptr L$174
L$136:
	cmp		dx,0aH
	jb		L$138
	jbe		L$153
	cmp		dx,20H
	jb		L$137
	jbe		L$142
	cmp		dx,26H
	je		L$162
	cmp		dx,21H
	je		L$148
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$137:
	cmp		dx,0bH
	je		L$151
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$138:
	cmp		dx,1
	jb		L$139
	jbe		L$145
	cmp		dx,7
	je		L$149
	cmp		dx,6
	je		L$162
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$139:
	test		dx,dx
	jne		L$174
	mov		ax,bx
	or		ah,80H
	mov		word ptr 2[si],ax
	cmp		word ptr _sf_mode,2
	jne		L$141
	cmp		bx,7fH
	je		L$140
	cmp		word ptr -8[bp],9
	je		L$141
L$140:
	cmp		di,7fH
	sete		al
	movzx		dx,al
	mov		ax,si
	call		near ptr sf_set_drum_
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$141:
	cmp		word ptr _sf_mode,3
	jne		L$174
	cmp		di,78H
	sete		al
	movzx		dx,al
	mov		ax,si
	call		near ptr sf_set_drum_
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$142:
	test		byte ptr 3[si],80H
	je		L$143
	mov		ax,word ptr 2[si]
	and		ax,7fH
	shl		ax,7
	jmp		L$144
L$143:
	xor		ax,dx
L$144:
	or		ax,di
	mov		word ptr 2[si],ax
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$145:
	mov		dx,word ptr 0cH[si]
	and		dx,7fH
	shl		di,7
	or		dx,di
	mov		word ptr 0cH[si],dx
L$146:
	cmp		ax,1
	je		L$147
	cmp		ax,21H
	jne		L$173
L$147:
	mov		ax,si
	call		near ptr sf_vibrato_channel_
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$148:
	mov		dx,word ptr 0cH[si]
	and		dx,3f80H
	or		dx,bx
	mov		word ptr 0cH[si],dx
	jmp		L$146
L$149:
	mov		dx,word ptr 8[si]
	xor		dh,dh
	and		dl,7fH
	shl		di,7
	or		dx,di
	mov		word ptr 8[si],dx
	jmp		L$146
L$150:
	mov		dx,word ptr 8[si]
	and		dx,3f80H
	or		dx,bx
	mov		word ptr 8[si],dx
	jmp		L$146
L$151:
	mov		dx,word ptr 0aH[si]
	xor		dh,dh
	and		dl,7fH
	shl		di,7
	or		dx,di
	mov		word ptr 0aH[si],dx
	jmp		L$146
L$152:
	mov		dx,word ptr 0aH[si]
	and		dx,3f80H
	or		dx,bx
	mov		word ptr 0aH[si],dx
	jmp		L$146
L$153:
	mov		ax,word ptr 6[si]
	xor		ah,ah
	and		al,7fH
	shl		di,7
	or		ax,di
	mov		word ptr 6[si],ax
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$154:
	mov		ax,word ptr 6[si]
	and		ax,3f80H
	or		ax,bx
	mov		word ptr 6[si],ax
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$155:
	cmp		byte ptr 1aH[si],0
	je		L$156
	cmp		bx,40H
	jae		L$156
	xor		bx,bx
	mov		dx,1
	mov		ax,word ptr -8[bp]
	call		near ptr sf_release_channel_
L$156:
	cmp		di,40H
	setae		al
	mov		byte ptr 1aH[si],al
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$157:
	mov		ax,word ptr 0eH[si]
	cmp		ax,0ffffH
	jne		L$158
	xor		ax,ax
L$158:
	xor		ah,ah
	and		al,7fH
	shl		di,7
	or		ax,di
	mov		word ptr 0eH[si],ax
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$159:
	mov		ax,word ptr 0eH[si]
	cmp		ax,0ffffH
	jne		L$160
	xor		ax,ax
L$160:
	and		ax,3f80H
	or		ax,di
	mov		word ptr 0eH[si],ax
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$161:
	mov		word ptr 0eH[si],0ffffH
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$162:
	cmp		ax,6
	jne		L$163
	mov		bx,word ptr 10H[si]
	and		bx,7fH
	mov		dx,di
	shl		dx,7
	or		bx,dx
	mov		word ptr 10H[si],bx
	jmp		L$164
L$163:
	mov		dx,word ptr 10H[si]
	and		dx,3f80H
	or		dx,di
	mov		word ptr 10H[si],dx
L$164:
	cmp		word ptr 0eH[si],0
	jne		L$165
	mov		ax,word ptr 10H[si]
	shr		ax,7
	imul		ax,64H
	mov		dx,word ptr 10H[si]
	xor		dh,dh
	and		dl,7fH
	add		ax,dx
	mov		word ptr 16H[si],ax
	jmp		L$168
L$165:
	cmp		word ptr 0eH[si],1
	jne		L$167
	mov		ax,word ptr 10H[si]
	xor		dx,dx
	add		ax,0e000H
	adc		dx,0ffffH
	mov		bx,64H
	xor		cx,cx
	call		far ptr __I4M
	mov		di,dx
	mov		cx,0dH
L$166:
	sar		di,1
	rcr		ax,1
	loop		L$166
	mov		word ptr 14H[si],ax
	jmp		L$168
L$167:
	cmp		word ptr 0eH[si],2
	jne		L$168
	cmp		ax,6
	jne		L$168
	sub		di,40H
	mov		word ptr 12H[si],di
L$168:
	mov		ax,si
	call		near ptr sf_pitch_channel_
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$169:
	mov		bx,1
	xor		dx,dx
	mov		ax,word ptr -8[bp]
	call		near ptr sf_release_channel_
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$170:
	xor		bx,bx
	xor		dx,dx
	mov		ax,word ptr -8[bp]
	call		near ptr sf_release_channel_
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
L$171:
	mov		word ptr 0aH[si],3fffH
	mov		word ptr 0eH[si],0ffffH
	mov		byte ptr 1bH[si],0
	mov		al,byte ptr 1bH[si]
	xor		ah,dh
	mov		word ptr 0cH[si],ax
	mov		word ptr 10H[si],ax
	mov		word ptr 16H[si],0c8H
	mov		word ptr 12H[si],0
	mov		ax,word ptr 12H[si]
	mov		word ptr 14H[si],ax
	cmp		byte ptr 1aH[si],0
	je		L$172
	xor		bx,bx
	mov		dx,1
	mov		ax,word ptr -8[bp]
	call		near ptr sf_release_channel_
L$172:
	mov		byte ptr 1aH[si],0
	mov		ax,si
	call		near ptr sf_pitch_channel_
	mov		ax,si
	call		near ptr sf_vibrato_channel_
L$173:
	mov		ax,si
	call		near ptr sf_gain_channel_
L$174:
	lea		sp,-6[bp]
	pop		di
	pop		si
	pop		cx
	pop		bp
	ret
	cld
sf_short_:
	push		bx
	push		cx
	push		si
	push		di
	mov		di,ax
	mov		bx,dx
	mov		si,ax
	and		si,0fH
	mov		cl,8
	shr		ax,cl
	ror		dx,cl
	xor		ax,dx
	and		dx,0ffH
	xor		ax,dx
	and		ax,7fH
	mov		cx,bx
	and		cx,7fH
	imul		bx,si,2aH
	add		bx,offset _sf_channels
	mov		dx,di
	and		dx,0f0H
	cmp		dx,0b0H
	jb		L$175
	jbe		L$178
	cmp		dx,0e0H
	je		L$181
	cmp		dx,0d0H
	je		L$180
	cmp		dx,0c0H
	je		L$179
	jmp		L$182
L$175:
	cmp		dx,90H
	je		L$176
	cmp		dx,80H
	je		L$177
	jmp		L$182
L$176:
	test		cx,cx
	je		L$177
	mov		bx,cx
	mov		dx,ax
	mov		ax,si
	call		near ptr sf_note_on_
	jmp		L$182
L$177:
	mov		dx,ax
	mov		ax,si
	call		near ptr sf_note_off_
	jmp		L$182
L$178:
	mov		bx,cx
	mov		dx,ax
	mov		ax,si
	call		near ptr sf_control_
	jmp		L$182
L$179:
	mov		dx,ax
	mov		ax,si
	call		near ptr sf_program_
	jmp		L$182
L$180:
	mov		byte ptr 1bH[bx],al
	mov		ax,bx
	call		near ptr sf_vibrato_channel_
	jmp		L$182
L$181:
	shl		cx,7
	or		ax,cx
	mov		word ptr 4[bx],ax
	mov		ax,bx
	call		near ptr sf_pitch_channel_
L$182:
	pop		di
	pop		si
	pop		cx
	pop		bx
	ret
	mov		ax,ax
sf_long_:
	push		dx
	push		si
	mov		es,cx
	cmp		byte ptr es:[bx],0f0H
	jne		L$192
	mov		fs,cx
	mov		si,bx
	add		si,ax
	cmp		byte ptr fs:-1[si],0f7H
	jne		L$192
	cmp		ax,6
	jne		L$185
	cmp		byte ptr es:1[bx],7eH
	jne		L$185
	cmp		byte ptr es:3[bx],9
	jne		L$185
	mov		al,byte ptr es:4[bx]
	cmp		al,3
	jne		L$183
	mov		ax,3
	call		near ptr sf_reset_
	pop		si
	pop		dx
	ret
L$183:
	cmp		al,1
	je		L$184
	cmp		al,2
	jne		L$192
L$184:
	xor		ax,ax
	call		near ptr sf_reset_
	pop		si
	pop		dx
	ret
L$185:
	cmp		ax,8
	jne		L$186
	cmp		byte ptr es:1[bx],7fH
	jne		L$186
	cmp		byte ptr es:2[bx],80H
	jae		L$186
	cmp		byte ptr es:3[bx],4
	jne		L$186
	cmp		byte ptr es:4[bx],1
	jne		L$186
	cmp		byte ptr es:5[bx],80H
	jae		L$186
	cmp		byte ptr es:6[bx],80H
	jae		L$186
	movzx		ax,byte ptr es:6[bx]
	shl		ax,7
	movzx		bx,byte ptr es:5[bx]
	or		bx,ax
	mov		ax,bx
	shr		ax,0dH
	add		bx,ax
	add		bx,bx
	mov		ax,word ptr _sf_headroom_gain
	mov		cx,0fH
	xor		si,si
	xor		dx,dx
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr _sf_output_gain,ax
	pop		si
	pop		dx
	ret
L$186:
	cmp		ax,9
	jne		L$187
	cmp		byte ptr es:1[bx],43H
	jne		L$187
	mov		dl,byte ptr es:2[bx]
	and		dl,0f0H
	cmp		dl,10H
	jne		L$187
	cmp		byte ptr es:3[bx],4cH
	jne		L$187
	cmp		byte ptr es:4[bx],0
	jne		L$187
	cmp		byte ptr es:5[bx],0
	jne		L$187
	cmp		byte ptr es:6[bx],7eH
	jne		L$187
	cmp		byte ptr es:7[bx],0
	jne		L$187
	mov		ax,2
	call		near ptr sf_reset_
	pop		si
	pop		dx
	ret
L$187:
	cmp		ax,0bH
	jne		L$192
	cmp		byte ptr es:1[bx],41H
	jne		L$192
	cmp		byte ptr es:3[bx],42H
	jne		L$192
	cmp		byte ptr es:4[bx],12H
	jne		L$192
	movzx		ax,byte ptr es:5[bx]
	movzx		dx,byte ptr es:6[bx]
	add		dx,ax
	movzx		ax,byte ptr es:7[bx]
	add		ax,dx
	movzx		dx,byte ptr es:8[bx]
	add		dx,ax
	movzx		ax,byte ptr es:9[bx]
	add		ax,dx
	test		al,7fH
	jne		L$192
	mov		al,byte ptr es:5[bx]
	cmp		al,40H
	je		L$188
	test		al,al
	jne		L$189
L$188:
	cmp		byte ptr es:6[bx],0
	jne		L$189
	cmp		byte ptr es:7[bx],7fH
	jne		L$189
	cmp		byte ptr es:8[bx],0
	jne		L$189
	mov		ax,1
	call		near ptr sf_reset_
	pop		si
	pop		dx
	ret
L$189:
	cmp		byte ptr es:5[bx],40H
	jne		L$192
	mov		al,byte ptr es:6[bx]
	and		al,0f0H
	cmp		al,10H
	jne		L$192
	cmp		byte ptr es:7[bx],15H
	jne		L$192
	mov		al,byte ptr es:6[bx]
	and		al,0fH
	xor		ah,ah
	test		ax,ax
	jne		L$190
	mov		ax,9
	jmp		L$191
L$190:
	cmp		ax,0aH
	jae		L$191
	dec		ax
L$191:
	cmp		byte ptr es:8[bx],0
	setne		dl
	xor		dh,dh
	imul		ax,2aH
	add		ax,offset _sf_channels
	call		near ptr sf_set_drum_
L$192:
	pop		si
	pop		dx
	ret
	mov		ax,ax
	cld
sf_sample_ptr_:
	push		si
	mov		si,ax
	mov		ax,bx
	cmp		word ptr 2[si],0
	jne		L$193
	cmp		cx,word ptr [si]
	je		L$194
L$193:
	mov		word ptr [si],cx
	mov		word ptr 2[si],0
	mov		bx,cx
	shl		bx,2
	les		dx,dword ptr _sf_bank+4
	add		bx,dx
	mov		dx,word ptr es:2[bx]
	mov		word ptr 4[si],dx
L$194:
	mov		dx,word ptr 4[si]
	pop		si
	ret
	mov		ax,ax
	cld
sf_sample_:
	push		bp
	mov		bp,sp
	push		si
	push		di
	sub		sp,0aH
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],bx
	mov		word ptr -8[bp],cx
	mov		si,bx
	mov		di,cx
	add		si,bx
	adc		di,cx
	mov		bx,si
	mov		cx,di
	call		near ptr sf_sample_ptr_
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
	cwd
	mov		word ptr -0eH[bp],ax
	mov		word ptr -6[bp],dx
	mov		ax,word ptr -0aH[bp]
	add		ax,1
	mov		dx,word ptr -8[bp]
	adc		dx,0
	cmp		dx,word ptr 6[bp]
	jne		L$195
	cmp		ax,word ptr 4[bp]
	jne		L$195
	cmp		si,0fffeH
	je		L$195
	mov		ax,word ptr es:2[bx]
	jmp		L$196
L$195:
	mov		bx,word ptr 4[bp]
	mov		cx,word ptr 6[bp]
	add		bx,bx
	adc		cx,cx
	mov		ax,word ptr -0cH[bp]
	call		near ptr sf_sample_ptr_
	mov		bx,ax
	mov		es,dx
	mov		ax,word ptr es:[bx]
L$196:
	cwd
	mov		bx,ax
	mov		ax,word ptr 8[bp]
	mov		si,word ptr 0aH[bp]
	mov		cl,9
	shr		ax,cl
	ror		si,cl
	xor		ax,si
	and		si,7fH
	xor		ax,si
	mov		di,bx
	sub		di,word ptr -0eH[bp]
	sbb		dx,word ptr -6[bp]
	mov		cx,0fH
	mov		bx,ax
	mov		ax,di
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	add		ax,word ptr -0eH[bp]
	adc		dx,word ptr -6[bp]
	lea		sp,-4[bp]
	pop		di
	pop		si
	pop		bp
	ret		8
sf_voice_render_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		si
	push		di
	sub		sp,6eH
	mov		word ptr -16H[bp],ax
	mov		word ptr -30H[bp],dx
	mov		bx,ax
	mov		bx,word ptr [bx]
	mov		word ptr -2aH[bp],bx
	mov		bx,ax
	mov		ax,word ptr 2[bx]
	mov		word ptr -28H[bp],ax
	movzx		ax,byte ptr 72H[bx]
	imul		ax,2aH
	mov		bx,offset _sf_channels
	add		bx,ax
	mov		word ptr -2eH[bp],bx
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 4[bx]
	mov		word ptr -0cH[bp],ax
	mov		ax,word ptr 6[bx]
	mov		word ptr -0aH[bp],ax
	mov		ax,word ptr 8[bx]
	mov		word ptr -1cH[bp],ax
	mov		ax,word ptr 0aH[bx]
	mov		word ptr -10H[bp],ax
	les		bx,dword ptr -2aH[bp]
	mov		ax,word ptr es:4[bx]
	mov		word ptr -2cH[bp],ax
	mov		ax,word ptr es:6[bx]
	mov		word ptr -20H[bp],ax
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 14H[bx]
	mov		word ptr -1aH[bp],ax
	mov		ax,word ptr 16H[bx]
	mov		word ptr -0eH[bp],ax
	mov		bx,word ptr -2aH[bp]
	mov		ax,word ptr es:8[bx]
	mov		word ptr -24H[bp],ax
	mov		ax,word ptr es:0aH[bx]
	mov		word ptr -22H[bp],ax
	mov		ax,word ptr -0eH[bp]
	or		ax,word ptr -1aH[bp]
	je		L$197
	mov		ax,word ptr -1aH[bp]
	sub		ax,word ptr -24H[bp]
	mov		dx,word ptr -0eH[bp]
	sbb		dx,word ptr -22H[bp]
	add		ax,1
	adc		dx,0
	jmp		L$198
L$197:
	xor		dx,dx
L$198:
	mov		word ptr -14H[bp],ax
	mov		word ptr -12H[bp],dx
	les		bx,dword ptr -2aH[bp]
	mov		ax,word ptr es:90H[bx]
	mov		word ptr -38H[bp],ax
	xor		ax,ax
	mov		word ptr -32H[bp],ax
	push		ax
	push		8000H
	mov		bx,word ptr -2eH[bp]
	mov		bx,word ptr 6[bx]
	xor		cx,cx
	add		bx,bx
	adc		cx,ax
	mov		si,word ptr -2aH[bp]
	mov		ax,word ptr es:7cH[si]
	cwd
	add		ax,bx
	adc		dx,cx
	xor		bx,bx
	xor		cx,cx
	call		near ptr sf_clip_
	mov		cx,ax
	mov		bx,dx
	mov		ax,8000H
	sub		ax,cx
	mov		dx,0
	sbb		dx,bx
	call		near ptr sf_pan_gain_
	mov		word ptr -46H[bp],ax
	mov		word ptr -42H[bp],dx
	mov		ax,cx
	mov		dx,bx
	call		near ptr sf_pan_gain_
	mov		word ptr -48H[bp],ax
	mov		word ptr -44H[bp],dx
	mov		word ptr -1eH[bp],offset _sf_mix
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 2cH[bx]
	mov		word ptr -76H[bp],ax
	mov		ax,word ptr 2eH[bx]
	mov		word ptr -74H[bp],ax
	mov		ax,word ptr 30H[bx]
	mov		word ptr -72H[bp],ax
	mov		ax,word ptr 32H[bx]
	mov		word ptr -70H[bp],ax
	mov		ax,0ffffH
	mov		word ptr -5aH[bp],ax
	mov		word ptr -58H[bp],ax
	mov		word ptr -56H[bp],0
L$199:
	cmp		word ptr -30H[bp],0
	je		L$232
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr -20H[bp]
	jb		L$200
	jne		L$232
	mov		ax,word ptr -0cH[bp]
	cmp		ax,word ptr -2cH[bp]
	jae		L$232
L$200:
	mov		bx,word ptr -16H[bp]
	cmp		byte ptr 4eH[bx],6
	je		L$232
	mov		ax,word ptr -30H[bp]
	cmp		ax,20H
	jbe		L$201
	mov		ax,20H
L$201:
	mov		word ptr -26H[bp],ax
	mov		bx,word ptr -16H[bp]
	mov		dx,word ptr 42H[bx]
	or		dx,word ptr 40H[bx]
	je		L$202
	cmp		word ptr 42H[bx],0
	jne		L$202
	cmp		ax,word ptr 40H[bx]
	jbe		L$202
	mov		ax,word ptr 40H[bx]
	mov		word ptr -26H[bp],ax
L$202:
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 52H[bx]
	or		ax,word ptr 50H[bx]
	je		L$203
	cmp		word ptr 52H[bx],0
	jne		L$203
	mov		ax,word ptr 50H[bx]
	cmp		ax,word ptr -26H[bp]
	jae		L$203
	mov		ax,word ptr 50H[bx]
	mov		word ptr -26H[bp],ax
L$203:
	mov		bx,word ptr -2aH[bp]
	add		bx,10H
	mov		ax,word ptr -16H[bp]
	add		ax,40H
	mov		dx,1
	mov		cx,word ptr -28H[bp]
	call		near ptr sf_env_level_
	mov		word ptr -3eH[bp],ax
	mov		word ptr -3aH[bp],dx
	or		ax,dx
	jne		L$204
	mov		bx,word ptr -16H[bp]
	cmp		byte ptr 4eH[bx],4
	jb		L$204
	mov		word ptr [bx],ax
	mov		word ptr 2[bx],ax
	jmp		near ptr L$235
L$204:
	mov		bx,word ptr -2aH[bp]
	add		bx,34H
	mov		ax,word ptr -16H[bp]
	add		ax,50H
	xor		dx,dx
	mov		cx,word ptr -28H[bp]
	call		near ptr sf_env_level_
	mov		word ptr -52H[bp],ax
	mov		di,dx
	mov		word ptr -3cH[bp],ax
	mov		word ptr -40H[bp],dx
	mov		ax,word ptr -16H[bp]
	add		ax,60H
	call		near ptr sf_lfo_level_
	mov		cx,ax
	mov		word ptr -54H[bp],dx
	mov		word ptr -36H[bp],ax
	mov		word ptr -34H[bp],dx
	mov		ax,word ptr -16H[bp]
	add		ax,68H
	call		near ptr sf_lfo_level_
	mov		word ptr -4eH[bp],ax
	mov		word ptr -4cH[bp],dx
	mov		si,word ptr -16H[bp]
	mov		si,word ptr 18H[si]
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 1aH[bx]
	mov		bx,word ptr -2eH[bp]
	add		si,word ptr 1eH[bx]
	adc		ax,word ptr 20H[bx]
	mov		word ptr -4aH[bp],ax
	les		bx,dword ptr -2aH[bp]
	mov		ax,word ptr es:88H[bx]
	cwd
	mov		bx,ax
	mov		word ptr -50H[bp],dx
	mov		ax,cx
	mov		dx,word ptr -54H[bp]
	mov		cx,word ptr -50H[bp]
	call		far ptr __I4M
	mov		cx,0fH
L$205:
	sar		dx,1
	rcr		ax,1
	loop		L$205
	add		si,ax
	mov		ax,word ptr -4aH[bp]
	adc		ax,dx
	mov		word ptr -4aH[bp],ax
	mov		bx,word ptr -2aH[bp]
	mov		ax,word ptr es:82H[bx]
	cwd
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -52H[bp]
	mov		dx,di
	call		far ptr __I4M
	mov		cx,0fH
L$206:
	sar		dx,1
	rcr		ax,1
	loop		L$206
	add		si,ax
	mov		ax,word ptr -4aH[bp]
	adc		ax,dx
	mov		word ptr -4aH[bp],ax
	mov		bx,word ptr -2aH[bp]
	mov		ax,word ptr es:8cH[bx]
	cwd
	mov		bx,word ptr -2eH[bp]
	mov		bx,word ptr 26H[bx]
	add		bx,ax
	mov		di,word ptr -2eH[bp]
	mov		cx,word ptr 28H[di]
	adc		cx,dx
	mov		ax,word ptr -4eH[bp]
	mov		dx,word ptr -4cH[bp]
	call		far ptr __I4M
	mov		cx,0fH
L$207:
	sar		dx,1
	rcr		ax,1
	loop		L$207
	add		ax,si
	adc		dx,word ptr -4aH[bp]
	mov		bx,word ptr -16H[bp]
	cmp		dx,word ptr 1eH[bx]
	jne		L$208
	cmp		ax,word ptr 1cH[bx]
	je		L$209
L$208:
	mov		word ptr 1cH[bx],ax
	mov		word ptr 1eH[bx],dx
	call		near ptr sf_ratio_
	mov		word ptr 0cH[bx],ax
	mov		word ptr 0eH[bx],dx
	mov		ax,dx
	or		ax,word ptr 0cH[bx]
	jne		L$209
	mov		word ptr 0cH[bx],1
	mov		word ptr 0eH[bx],ax
L$209:
	les		bx,dword ptr -2aH[bp]
	cmp		word ptr es:86H[bx],0
	jne		L$210
	cmp		word ptr es:84H[bx],0
	je		L$214
L$210:
	les		bx,dword ptr -2aH[bp]
	mov		ax,word ptr es:86H[bx]
	cwd
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -36H[bp]
	mov		dx,word ptr -34H[bp]
	call		far ptr __I4M
	mov		bx,ax
	mov		di,dx
	mov		cx,0fH
L$211:
	sar		di,1
	rcr		bx,1
	loop		L$211
	mov		si,word ptr -2aH[bp]
	mov		ax,word ptr es:80H[si]
	cwd
	mov		si,ax
	add		si,bx
	adc		di,dx
	mov		bx,word ptr -2aH[bp]
	mov		ax,word ptr es:84H[bx]
	cwd
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -3cH[bp]
	mov		dx,word ptr -40H[bp]
	call		far ptr __I4M
	mov		cx,0fH
L$212:
	sar		dx,1
	rcr		ax,1
	loop		L$212
	mov		bx,si
	add		bx,ax
	mov		cx,di
	adc		cx,dx
	mov		si,word ptr -16H[bp]
	cmp		cx,word ptr 2aH[si]
	jne		L$213
	cmp		bx,word ptr 28H[si]
	je		L$214
L$213:
	mov		word ptr 28H[si],bx
	mov		word ptr 2aH[si],cx
	push		word ptr _sf_tan_values
	mov		si,word ptr -2aH[bp]
	push		dword ptr es:74H[si]
	mov		ax,word ptr -16H[bp]
	add		ax,34H
	call		near ptr sf_filter_coeff_
L$214:
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 20H[bx]
	mov		dx,word ptr 22H[bx]
	les		bx,dword ptr -2aH[bp]
	cmp		word ptr es:8aH[bx],0
	je		L$216
	mov		ax,word ptr es:8aH[bx]
	cwd
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -36H[bp]
	mov		dx,word ptr -34H[bp]
	call		far ptr __I4M
	mov		bx,ax
	mov		di,dx
	mov		cx,0fH
L$215:
	sar		di,1
	rcr		bx,1
	loop		L$215
	mov		si,word ptr -2aH[bp]
	mov		ax,word ptr es:7eH[si]
	cwd
	sub		ax,bx
	sbb		dx,di
	call		near ptr sf_gain_
	mov		bx,word ptr -16H[bp]
	mov		bx,word ptr 24H[bx]
	mov		si,word ptr -16H[bp]
	mov		si,word ptr 26H[si]
	mov		cx,0fH
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
L$216:
	mov		bx,word ptr -2eH[bp]
	mov		bx,word ptr 22H[bx]
	mov		si,word ptr -2eH[bp]
	mov		si,word ptr 24H[si]
	mov		cx,0fH
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	cmp		dx,word ptr -32H[bp]
	jg		L$217
	jne		L$218
	cmp		ax,word ptr -38H[bp]
	jbe		L$218
L$217:
	mov		ax,word ptr -38H[bp]
	mov		dx,word ptr -32H[bp]
L$218:
	mov		cx,0fH
	mov		bx,word ptr -3eH[bp]
	mov		si,word ptr -3aH[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr -4cH[bp],ax
	mov		di,dx
	mov		bx,word ptr -46H[bp]
	mov		si,word ptr -42H[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr -62H[bp],ax
	mov		word ptr -60H[bp],dx
	mov		bx,word ptr -48H[bp]
	mov		si,word ptr -44H[bp]
	mov		ax,word ptr -4cH[bp]
	mov		dx,di
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		word ptr -5eH[bp],ax
	mov		word ptr -5cH[bp],dx
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 34H[bx]
	mov		word ptr -6eH[bp],ax
	mov		ax,word ptr 36H[bx]
	mov		word ptr -6cH[bp],ax
	mov		ax,word ptr 38H[bx]
	mov		word ptr -6aH[bp],ax
	mov		ax,word ptr 3aH[bx]
	mov		word ptr -68H[bp],ax
	mov		ax,word ptr 3cH[bx]
	mov		word ptr -66H[bp],ax
	mov		ax,word ptr 3eH[bx]
	mov		word ptr -64H[bp],ax
	mov		word ptr -18H[bp],0
L$219:
	mov		ax,word ptr -18H[bp]
	cmp		ax,word ptr -26H[bp]
	jae		L$231
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr -20H[bp]
	jb		L$220
	jne		L$231
	mov		ax,word ptr -0cH[bp]
	cmp		ax,word ptr -2cH[bp]
	jae		L$231
L$220:
	mov		ax,word ptr -60H[bp]
	or		ax,word ptr -62H[bp]
	jne		L$221
	mov		ax,word ptr -5cH[bp]
	or		ax,word ptr -5eH[bp]
	jne		L$221
	mov		ax,word ptr -6cH[bp]
	or		ax,word ptr -6eH[bp]
	je		L$227
L$221:
	push		word ptr -10H[bp]
	push		word ptr -1cH[bp]
	mov		ax,word ptr -12H[bp]
	or		ax,word ptr -14H[bp]
	je		L$222
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr -0eH[bp]
	jne		L$222
	mov		ax,word ptr -0cH[bp]
	cmp		ax,word ptr -1aH[bp]
	jne		L$222
	mov		ax,word ptr -24H[bp]
	mov		dx,word ptr -22H[bp]
	jmp		L$223
L$222:
	mov		ax,word ptr -0cH[bp]
	add		ax,1
	mov		dx,word ptr -0aH[bp]
	adc		dx,0
L$223:
	push		dx
	push		ax
	lea		ax,-5aH[bp]
	mov		bx,word ptr -0cH[bp]
	mov		cx,word ptr -0aH[bp]
	call		near ptr sf_sample_
	lea		bx,-76H[bp]
	mov		di,word ptr -1eH[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	cmp		dword ptr 8[bx],0
	je		L$226
	shl		eax,8
	imul		dword ptr 8[bx]
	shrd		eax,edx,1cH
	mov		ecx,eax
	add		eax,dword ptr [bx]
	cmp		eax,0fe000000H
	jge		L$224
	mov		eax,0fe000000H
L$224:
	cmp		eax,1ffffffH
	jle		L$225
	mov		eax,1ffffffH
L$225:
	mov		esi,eax
	imul		dword ptr 0cH[bx]
	shrd		eax,edx,1cH
	mov		edx,dword ptr 4[bx]
	lea		edx,[edx+ecx*2]
	sub		edx,eax
	mov		dword ptr [bx],edx
	mov		eax,esi
	imul		dword ptr 10H[bx]
	shrd		eax,edx,1cH
	sub		ecx,eax
	mov		dword ptr 4[bx],ecx
	mov		eax,esi
	sar		eax,8
L$226:
	mov		ecx,eax
	imul		dword ptr 14H[bx]
	shrd		eax,edx,0fH
	add		dword ptr [di],eax
	mov		eax,ecx
	imul		dword ptr 18H[bx]
	shrd		eax,edx,0fH
	add		dword ptr 4[di],eax
L$227:
	add		word ptr -1eH[bp],8
	mov		bx,word ptr -16H[bp]
	mov		ax,word ptr 0cH[bx]
	add		word ptr -1cH[bp],ax
	mov		ax,word ptr 0eH[bx]
	adc		word ptr -10H[bp],ax
	mov		ax,word ptr -10H[bp]
	shr		ax,8
	xor		dx,dx
	add		word ptr -0cH[bp],ax
	adc		word ptr -0aH[bp],dx
	mov		byte ptr -0fH[bp],0
	mov		ax,word ptr -12H[bp]
	or		ax,word ptr -14H[bp]
	je		L$230
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr -0eH[bp]
	ja		L$228
	jne		L$230
	mov		ax,word ptr -0cH[bp]
	cmp		ax,word ptr -1aH[bp]
	jbe		L$230
L$228:
	mov		ax,word ptr -14H[bp]
	sub		word ptr -0cH[bp],ax
	mov		ax,word ptr -12H[bp]
	sbb		word ptr -0aH[bp],ax
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr -0eH[bp]
	ja		L$229
	jne		L$230
	mov		ax,word ptr -0cH[bp]
	cmp		ax,word ptr -1aH[bp]
	jbe		L$230
L$229:
	mov		ax,word ptr -0cH[bp]
	sub		ax,word ptr -24H[bp]
	mov		dx,word ptr -0aH[bp]
	sbb		dx,word ptr -22H[bp]
	mov		bx,word ptr -14H[bp]
	mov		cx,word ptr -12H[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		ecx,10H
	mov		cx,bx
	cdq
	idiv		ecx
	mov		edx,eax
	shr		edx,10H
	mov		bx,ax
	mov		cx,dx
	mov		ax,word ptr -14H[bp]
	mov		dx,word ptr -12H[bp]
	call		far ptr __U4M
	sub		word ptr -0cH[bp],ax
	sbb		word ptr -0aH[bp],dx
L$230:
	inc		word ptr -18H[bp]
	jmp		near ptr L$219
L$231:
	push		1
	mov		bx,word ptr -16H[bp]
	movzx		ax,byte ptr 73H[bx]
	push		ax
	mov		bx,word ptr -2aH[bp]
	add		bx,10H
	mov		ax,word ptr -16H[bp]
	add		ax,40H
	mov		dx,word ptr -26H[bp]
	mov		cx,word ptr -28H[bp]
	call		near ptr sf_env_advance_
	push		0
	mov		bx,word ptr -16H[bp]
	movzx		ax,byte ptr 73H[bx]
	push		ax
	mov		bx,word ptr -2aH[bp]
	add		bx,34H
	mov		ax,word ptr -16H[bp]
	add		ax,50H
	mov		dx,word ptr -26H[bp]
	mov		cx,word ptr -28H[bp]
	call		near ptr sf_env_advance_
	les		bx,dword ptr -2aH[bp]
	mov		bx,word ptr es:60H[bx]
	mov		si,word ptr -2aH[bp]
	mov		cx,word ptr es:62H[si]
	mov		ax,word ptr -16H[bp]
	add		ax,60H
	mov		dx,word ptr -26H[bp]
	call		near ptr sf_lfo_advance_
	mov		es,word ptr -28H[bp]
	mov		bx,si
	mov		bx,word ptr es:64H[bx]
	mov		cx,word ptr es:66H[si]
	mov		ax,word ptr -16H[bp]
	add		ax,68H
	mov		dx,word ptr -26H[bp]
	call		near ptr sf_lfo_advance_
	mov		ax,word ptr -26H[bp]
	sub		word ptr -30H[bp],ax
	jmp		near ptr L$199
L$232:
	mov		ax,word ptr -0cH[bp]
	mov		bx,word ptr -16H[bp]
	mov		word ptr 4[bx],ax
	mov		ax,word ptr -0aH[bp]
	mov		word ptr 6[bx],ax
	mov		ax,word ptr -1cH[bp]
	mov		word ptr 8[bx],ax
	mov		ax,word ptr -10H[bp]
	mov		word ptr 0aH[bx],ax
	mov		ax,word ptr -76H[bp]
	mov		word ptr 2cH[bx],ax
	mov		ax,word ptr -74H[bp]
	mov		word ptr 2eH[bx],ax
	mov		ax,word ptr -72H[bp]
	mov		word ptr 30H[bx],ax
	mov		ax,word ptr -70H[bp]
	mov		word ptr 32H[bx],ax
	mov		ax,word ptr -0aH[bp]
	cmp		ax,word ptr -20H[bp]
	ja		L$234
	jne		L$233
	mov		ax,word ptr -0cH[bp]
	cmp		ax,word ptr -2cH[bp]
	jae		L$234
L$233:
	cmp		byte ptr 4eH[bx],6
	jne		L$235
L$234:
	mov		bx,word ptr -16H[bp]
	mov		dword ptr [bx],0
L$235:
	lea		sp,-8[bp]
	pop		di
	pop		si
	pop		cx
	pop		bx
	pop		bp
	ret
	cld
sf_render_:
	push		bp
	mov		bp,sp
	push		cx
	push		si
	push		di
	sub		sp,8
	mov		word ptr -0cH[bp],ax
	mov		word ptr -0aH[bp],dx
	mov		word ptr -8[bp],bx
	xor		di,di
L$236:
	mov		ax,word ptr -8[bp]
	add		ax,ax
	cmp		di,ax
	jae		L$237
	mov		bx,di
	shl		bx,2
	xor		ax,ax
	mov		word ptr _sf_mix[bx],ax
	mov		word ptr _sf_mix+2[bx],ax
	inc		di
	jmp		L$236
L$237:
	xor		di,di
L$238:
	cmp		di,word ptr _sf_limit
	jae		L$241
	imul		bx,di,76H
	mov		ax,word ptr _sf_voices[bx]
	mov		dx,word ptr _sf_voices+2[bx]
	test		dx,dx
	jne		L$239
	test		ax,ax
	je		L$240
L$239:
	mov		ax,offset _sf_voices
	add		ax,bx
	mov		dx,word ptr -8[bp]
	call		near ptr sf_voice_render_
L$240:
	inc		di
	jmp		L$238
L$241:
	cmp		word ptr _sf_output_gain,8000H
	jne		L$243
	xor		di,di
L$242:
	mov		ax,word ptr -8[bp]
	add		ax,ax
	cmp		di,ax
	jae		L$174
	push		0
	push		7fffH
	mov		bx,di
	shl		bx,2
	mov		ax,word ptr _sf_mix[bx]
	mov		dx,word ptr _sf_mix+2[bx]
	mov		bx,8000H
	mov		cx,0ffffH
	call		near ptr sf_clip_
	mov		bx,di
	add		bx,di
	mov		es,word ptr -0aH[bp]
	add		bx,word ptr -0cH[bp]
	mov		word ptr es:[bx],ax
	inc		di
	jmp		L$242
L$243:
	xor		di,di
L$244:
	mov		ax,word ptr -8[bp]
	add		ax,ax
	cmp		di,ax
	jae		L$174
	push		0
	push		7fffH
	mov		ax,word ptr _sf_output_gain
	mov		bx,di
	shl		bx,2
	mov		dx,word ptr _sf_mix[bx]
	mov		word ptr -0eH[bp],dx
	mov		dx,word ptr _sf_mix+2[bx]
	mov		cx,0fH
	mov		bx,ax
	xor		si,si
	mov		ax,word ptr -0eH[bp]
	shl		edx,10H
	mov		dx,ax
	mov		eax,edx
	shl		esi,10H
	mov		si,bx
	imul		esi
	shrd		eax,edx,cl
	mov		edx,eax
	shr		edx,10H
	mov		bx,8000H
	mov		cx,0ffffH
	call		near ptr sf_clip_
	mov		bx,di
	add		bx,di
	mov		es,word ptr -0aH[bp]
	add		bx,word ptr -0cH[bp]
	mov		word ptr es:[bx],ax
	inc		di
	jmp		L$244
	cld
L$245:
    DW	offset L$246
    DW	offset L$247
    DW	offset L$250
    DW	offset L$252
    DW	offset L$253
sf_dispatch_:
	push		si
	push		di
	mov		si,ax
	mov		ax,dx
	mov		dx,bx
	cmp		word ptr _sf_ready,0
	je		L$254
	lea		bx,-2[si]
	cmp		bx,4
	ja		L$254
	add		bx,bx
	jmp		word ptr cs:L$245[bx]
L$246:
	cmp		dl,80H
	jb		L$254
	cmp		dl,0f0H
	jae		L$254
	mov		ax,dx
	mov		dx,cx
	call		near ptr sf_short_
	mov		ax,1
	pop		di
	pop		si
	ret
L$247:
	cmp		ax,6
	je		L$248
	cmp		ax,8
	je		L$248
	cmp		ax,9
	je		L$248
	cmp		ax,0bH
	jne		L$254
L$248:
	mov		bx,cx
	or		bx,dx
	je		L$254
	test		cx,cx
	je		L$254
	xor		si,si
	xor		bx,bx
	mov		di,dx
	add		di,ax
	adc		bx,si
	cmp		bx,1
	ja		L$254
	jne		L$249
	test		di,di
	ja		L$254
L$249:
	mov		bx,dx
	call		near ptr sf_long_
	mov		ax,1
	pop		di
	pop		si
	ret
L$250:
	test		ax,ax
	je		L$254
	cmp		ax,200H
	ja		L$254
	mov		bx,cx
	or		bx,dx
	je		L$254
	test		cx,cx
	je		L$254
	mov		si,ax
	shl		si,2
	xor		bx,bx
	add		si,dx
	adc		bx,bx
	cmp		bx,1
	ja		L$254
	jne		L$251
	test		si,si
	ja		L$254
L$251:
	mov		bx,ax
	mov		ax,dx
	mov		dx,cx
	call		near ptr sf_render_
	mov		ax,1
	pop		di
	pop		si
	ret
L$252:
	xor		ax,ax
	call		near ptr sf_reset_
	mov		ax,1
	pop		di
	pop		si
	ret
L$253:
	call		near ptr sf_stop_playback_
	mov		ax,1
	pop		di
	pop		si
	ret
L$254:
	xor		ax,ax
	pop		di
	pop		si
	ret
	mov		ax,ax
sf_set_rate_:
	cmp		ax,0ac44H
	je		L$255
	cmp		ax,0bb80H
	je		L$255
	xor		ax,ax
	ret
L$255:
	cmp		word ptr _sf_ready,0
	je		L$256
	cmp		ax,word ptr _sf_rate
	je		L$256
	xor		ax,ax
	ret
L$256:
	mov		word ptr _sf_rate,ax
	mov		ax,1
	ret
sf_set_headroom_:
	push		bx
	push		cx
	push		dx
	cmp		word ptr _sf_ready,0
	jne		L$257
	cmp		ax,18H
	jbe		L$258
L$257:
	xor		ax,ax
	jmp		L$259
L$258:
	xor		dx,dx
	mov		bx,0aH
	xor		cx,cx
	call		far ptr __I4M
	call		near ptr sf_gain_
	mov		word ptr _sf_headroom_gain,ax
	mov		ax,1
L$259:
	pop		dx
	pop		cx
	pop		bx
	ret
sf_open_:
	push		cx
	push		si
	mov		si,bx
	cmp		word ptr _sf_ready,0
	jne		L$261
	test		dx,dx
	jne		L$260
	test		ax,ax
	je		L$261
L$260:
	cmp		bx,20H
	jb		L$261
	cmp		bx,80H
	jbe		L$262
L$261:
	xor		ax,ax
	pop		si
	pop		cx
	ret
L$262:
	push		word ptr _sf_rate
	mov		bx,offset _sf_bank
	mov		cx,ds
	call		far ptr sf_load_
	cmp		ax,1
	jne		L$265
	mov		word ptr _sf_limit,si
	mov		ax,word ptr _sf_rate
	xor		dx,dx
	mov		si,64H
	div		si
	mov		word ptr _sf_quick_release,ax
	cmp		word ptr _sf_rate,0bb80H
	jne		L$263
	mov		ax,offset _sf_tan_48000
	jmp		L$264
L$263:
	mov		ax,offset _sf_tan_44100
L$264:
	mov		word ptr _sf_tan_values,ax
	xor		ax,ax
	call		near ptr sf_reset_
	mov		ax,1
	mov		word ptr _sf_ready,ax
L$265:
	pop		si
	pop		cx
	ret
sf_close_:
	push		dx
	cmp		word ptr _sf_ready,0
	je		L$266
	xor		ax,ax
	mov		word ptr _sf_ready,ax
	mov		word ptr _sf_limit,ax
	mov		ax,offset _sf_bank
	mov		dx,ds
	call		far ptr sf_unload_
L$266:
	pop		dx
	ret
dispatch_irq_:
	push		bp
	mov		bp,sp
	push		bx
	push		cx
	push		dx
	mov		bx,word ptr _request_data
	mov		cx,word ptr _request_data+2
	mov		dx,word ptr _request_value
	mov		ax,word ptr _request_command
	call		near ptr sf_dispatch_
	pop		dx
	pop		cx
	pop		bx
	pop		bp
	retf
	mov		ax,ax
	cld
LIBMAIN:
	push		bp
	mov		bp,sp
	push		ds
	mov		ax,DGROUP:CONST
	mov		ds,ax
	mov		ax,1
	pop		ds
	pop		bp
	retf		0aH
	cld
L$267:
    DW	offset L$269
    DW	offset L$270
    DW	offset L$275
    DW	offset L$275
    DW	offset L$275
    DW	offset L$275
    DW	offset L$271
    DW	offset L$272
    DW	offset L$273
    DW	offset L$274
	mov		ax,ax
SFCORE:
	push		bp
	mov		bp,sp
	push		ds
	mov		ax,DGROUP:CONST
	mov		ds,ax
	mov		dx,word ptr 6[bp]
	mov		cx,word ptr 8[bp]
	mov		ax,word ptr 0aH[bp]
	mov		bx,word ptr 0cH[bp]
	test		bh,80H
	je		L$268
	and		bh,7fH
	mov		word ptr _request_command,bx
	mov		word ptr _request_value,ax
	mov		word ptr _request_data,dx
	mov		word ptr _request_data+2,cx
	pushad
	push		ds
	push		es
	mov		word ptr _saved_ss,ss
	mov		word ptr _saved_sp,sp
	pushf
	pop		ax
	cli
	mov		bx,ds
	mov		ss,bx
	mov		sp,offset _irq_stack+2000H
	push		ax
	popf
	call		far ptr dispatch_irq_
	mov		word ptr _request_result,ax
	pushf
	pop		bx
	cli
	mov		ss,word ptr _saved_ss
	mov		sp,word ptr _saved_sp
	push		bx
	popf
	pop		es
	pop		ds
	popad
	mov		ax,word ptr _request_result
	jmp		L$276
L$268:
	cmp		bx,9
	ja		L$275
	add		bx,bx
	jmp		word ptr cs:L$267[bx]
L$269:
	mov		ax,5342H
	pop		ds
	pop		bp
	retf		8
L$270:
	mov		bx,ax
	mov		ax,dx
	mov		dx,cx
	call		near ptr sf_open_
	pop		ds
	pop		bp
	retf		8
L$271:
	call		near ptr sf_close_
	mov		ax,1
	pop		ds
	pop		bp
	retf		8
L$272:
	mov		ax,ds
	pop		ds
	pop		bp
	retf		8
L$273:
	call		near ptr sf_set_rate_
	pop		ds
	pop		bp
	retf		8
L$274:
	call		near ptr sf_set_headroom_
	pop		ds
	pop		bp
	retf		8
L$275:
	xor		ax,ax
L$276:
	pop		ds
	pop		bp
	retf		8
SFIRQ_TEXT		ENDS
CONST		SEGMENT	WORD PUBLIC USE16 'DATA'
CONST		ENDS
CONST2		SEGMENT	PARA PUBLIC USE16 'DATA'
_sf_pitch_table:
    DB	0, 0, 0, 1, 0a5H, 7bH, 1, 1
    DB	7eH, 0f9H, 2, 1, 8dH, 79H, 4, 1
    DB	0d5H, 0fbH, 5, 1, 5aH, 80H, 7, 1
    DB	1fH, 7, 9, 1, 28H, 90H, 0aH, 1
    DB	78H, 1bH, 0cH, 1, 12H, 0a9H, 0dH, 1
    DB	0f9H, 38H, 0fH, 1, 32H, 0cbH, 10H, 1
    DB	0bfH, 5fH, 12H, 1, 0a4H, 0f6H, 13H, 1
    DB	0e4H, 8fH, 15H, 1, 84H, 2bH, 17H, 1
    DB	86H, 0c9H, 18H, 1, 0edH, 69H, 1aH, 1
    DB	0bfH, 0cH, 1cH, 1, 0fdH, 0b1H, 1dH, 1
    DB	0acH, 59H, 1fH, 1, 0d0H, 3, 21H, 1
    DB	6bH, 0b0H, 22H, 1, 82H, 5fH, 24H, 1
    DB	18H, 11H, 26H, 1, 32H, 0c5H, 27H, 1
    DB	0d2H, 7bH, 29H, 1, 0fcH, 34H, 2bH, 1
    DB	0b5H, 0f0H, 2cH, 1, 0, 0afH, 2eH, 1
    DB	0e1H, 6fH, 30H, 1, 5bH, 33H, 32H, 1
    DB	73H, 0f9H, 33H, 1, 2cH, 0c2H, 35H, 1
    DB	8bH, 8dH, 37H, 1, 93H, 5bH, 39H, 1
    DB	48H, 2cH, 3bH, 1, 0aeH, 0ffH, 3cH, 1
    DB	0c9H, 0d5H, 3eH, 1, 9eH, 0aeH, 40H, 1
    DB	30H, 8aH, 42H, 1, 83H, 68H, 44H, 1
    DB	9bH, 49H, 46H, 1, 7dH, 2dH, 48H, 1
    DB	2cH, 14H, 4aH, 1, 0adH, 0fdH, 4bH, 1
    DB	4, 0eaH, 4dH, 1, 36H, 0d9H, 4fH, 1
    DB	45H, 0cbH, 51H, 1, 37H, 0c0H, 53H, 1
    DB	11H, 0b8H, 55H, 1, 0d5H, 0b2H, 57H, 1
    DB	89H, 0b0H, 59H, 1, 30H, 0b1H, 5bH, 1
    DB	0d0H, 0b4H, 5dH, 1, 6dH, 0bbH, 5fH, 1
    DB	0bH, 0c5H, 61H, 1, 0aeH, 0d1H, 63H, 1
    DB	5cH, 0e1H, 65H, 1, 17H, 0f4H, 67H, 1
    DB	0e6H, 9, 6aH, 1, 0cdH, 22H, 6cH, 1
    DB	0d0H, 3eH, 6eH, 1, 0f3H, 5dH, 70H, 1
    DB	3dH, 80H, 72H, 1, 0b0H, 0a5H, 74H, 1
    DB	52H, 0ceH, 76H, 1, 28H, 0faH, 78H, 1
    DB	36H, 29H, 7bH, 1, 81H, 5bH, 7dH, 1
    DB	0dH, 91H, 7fH, 1, 0e1H, 0c9H, 81H, 1
    DB	0, 6, 84H, 1, 70H, 45H, 86H, 1
    DB	35H, 88H, 88H, 1, 54H, 0ceH, 8aH, 1
    DB	0d3H, 17H, 8dH, 1, 0b6H, 64H, 8fH, 1
    DB	2, 0b5H, 91H, 1, 0bcH, 8, 94H, 1
    DB	0eaH, 5fH, 96H, 1, 91H, 0baH, 98H, 1
    DB	0b5H, 18H, 9bH, 1, 5cH, 7aH, 9dH, 1
    DB	8cH, 0dfH, 9fH, 1, 48H, 48H, 0a2H, 1
    DB	98H, 0b4H, 0a4H, 1, 7fH, 24H, 0a7H, 1
    DB	3, 98H, 0a9H, 1, 2bH, 0fH, 0acH, 1
    DB	0faH, 89H, 0aeH, 1, 76H, 8, 0b1H, 1
    DB	0a5H, 8aH, 0b3H, 1, 8dH, 10H, 0b6H, 1
    DB	33H, 9aH, 0b8H, 1, 9cH, 27H, 0bbH, 1
    DB	0ceH, 0b8H, 0bdH, 1, 0ceH, 4dH, 0c0H, 1
    DB	0a3H, 0e6H, 0c2H, 1, 52H, 83H, 0c5H, 1
    DB	0e0H, 23H, 0c8H, 1, 54H, 0c8H, 0caH, 1
    DB	0b3H, 70H, 0cdH, 1, 3, 1dH, 0d0H, 1
    DB	4aH, 0cdH, 0d2H, 1, 8eH, 81H, 0d5H, 1
    DB	0d4H, 39H, 0d8H, 1, 23H, 0f6H, 0daH, 1
    DB	80H, 0b6H, 0ddH, 1, 0f2H, 7aH, 0e0H, 1
    DB	7eH, 43H, 0e3H, 1, 2cH, 10H, 0e6H, 1
    DB	0, 0e1H, 0e8H, 1, 1, 0b6H, 0ebH, 1
    DB	35H, 8fH, 0eeH, 1, 0a2H, 6cH, 0f1H, 1
    DB	50H, 4eH, 0f4H, 1, 43H, 34H, 0f7H, 1
    DB	82H, 1eH, 0faH, 1, 15H, 0dH, 0fdH, 1
    DB	0, 0, 0, 2
_sf_pan_table:
    DB	0, 0, 0, 8, 50H, 0bH, 0dbH, 0dH
    DB	0, 10H, 0e3H, 11H, 99H, 13H, 2aH, 15H
    DB	0a1H, 16H, 0, 18H, 4cH, 19H, 88H, 1aH
    DB	0b6H, 1bH, 0d8H, 1cH, 0efH, 1dH, 0fcH, 1eH
    DB	0, 20H, 0fcH, 20H, 0f1H, 21H, 0dfH, 22H
    DB	0c7H, 23H, 0a9H, 24H, 86H, 25H, 5eH, 26H
    DB	31H, 27H, 0, 28H, 0cbH, 28H, 92H, 29H
    DB	55H, 2aH, 15H, 2bH, 0d1H, 2bH, 8bH, 2cH
    DB	41H, 2dH, 0f5H, 2dH, 0a6H, 2eH, 54H, 2fH
    DB	0, 30H, 0a9H, 30H, 51H, 31H, 0f6H, 31H
    DB	99H, 32H, 3aH, 33H, 0d9H, 33H, 76H, 34H
    DB	11H, 35H, 0aaH, 35H, 42H, 36H, 0d8H, 36H
    DB	6dH, 37H, 0, 38H, 92H, 38H, 22H, 39H
    DB	0b0H, 39H, 3eH, 3aH, 0caH, 3aH, 54H, 3bH
    DB	0deH, 3bH, 66H, 3cH, 0edH, 3cH, 73H, 3dH
    DB	0f8H, 3dH, 7bH, 3eH, 0feH, 3eH, 7fH, 3fH
    DB	0, 40H, 80H, 40H, 0feH, 40H, 7cH, 41H
    DB	0f8H, 41H, 74H, 42H, 0efH, 42H, 69H, 43H
    DB	0e2H, 43H, 5aH, 44H, 0d2H, 44H, 48H, 45H
    DB	0beH, 45H, 33H, 46H, 0a7H, 46H, 1bH, 47H
    DB	8eH, 47H, 0, 48H, 71H, 48H, 0e2H, 48H
    DB	52H, 49H, 0c2H, 49H, 30H, 4aH, 9eH, 4aH
    DB	0cH, 4bH, 79H, 4bH, 0e5H, 4bH, 51H, 4cH
    DB	0bcH, 4cH, 26H, 4dH, 90H, 4dH, 0f9H, 4dH
    DB	62H, 4eH, 0caH, 4eH, 32H, 4fH, 99H, 4fH
    DB	0, 50H, 66H, 50H, 0ccH, 50H, 31H, 51H
    DB	96H, 51H, 0faH, 51H, 5dH, 52H, 0c1H, 52H
    DB	23H, 53H, 86H, 53H, 0e8H, 53H, 49H, 54H
    DB	0aaH, 54H, 0bH, 55H, 6bH, 55H, 0caH, 55H
    DB	2aH, 56H, 89H, 56H, 0e7H, 56H, 45H, 57H
    DB	0a3H, 57H, 0, 58H, 5dH, 58H, 0b9H, 58H
    DB	16H, 59H, 71H, 59H, 0cdH, 59H, 28H, 5aH
    DB	82H, 5aH, 0ddH, 5aH, 37H, 5bH, 90H, 5bH
    DB	0eaH, 5bH, 43H, 5cH, 9bH, 5cH, 0f4H, 5cH
    DB	4cH, 5dH, 0a3H, 5dH, 0fbH, 5dH, 52H, 5eH
    DB	0a8H, 5eH, 0ffH, 5eH, 55H, 5fH, 0abH, 5fH
    DB	0, 60H, 55H, 60H, 0aaH, 60H, 0ffH, 60H
    DB	53H, 61H, 0a7H, 61H, 0fbH, 61H, 4eH, 62H
    DB	0a1H, 62H, 0f4H, 62H, 47H, 63H, 99H, 63H
    DB	0ecH, 63H, 3dH, 64H, 8fH, 64H, 0e0H, 64H
    DB	31H, 65H, 82H, 65H, 0d3H, 65H, 23H, 66H
    DB	73H, 66H, 0c3H, 66H, 13H, 67H, 62H, 67H
    DB	0b1H, 67H, 0, 68H, 4fH, 68H, 9dH, 68H
    DB	0ebH, 68H, 39H, 69H, 87H, 69H, 0d4H, 69H
    DB	22H, 6aH, 6fH, 6aH, 0bcH, 6aH, 8, 6bH
    DB	55H, 6bH, 0a1H, 6bH, 0edH, 6bH, 39H, 6cH
    DB	84H, 6cH, 0d0H, 6cH, 1bH, 6dH, 66H, 6dH
    DB	0b1H, 6dH, 0fbH, 6dH, 46H, 6eH, 90H, 6eH
    DB	0daH, 6eH, 24H, 6fH, 6dH, 6fH, 0b7H, 6fH
    DB	0, 70H, 49H, 70H, 92H, 70H, 0dbH, 70H
    DB	23H, 71H, 6bH, 71H, 0b4H, 71H, 0fcH, 71H
    DB	43H, 72H, 8bH, 72H, 0d2H, 72H, 1aH, 73H
    DB	61H, 73H, 0a8H, 73H, 0eeH, 73H, 35H, 74H
    DB	7bH, 74H, 0c2H, 74H, 8, 75H, 4eH, 75H
    DB	93H, 75H, 0d9H, 75H, 1eH, 76H, 64H, 76H
    DB	0a9H, 76H, 0eeH, 76H, 33H, 77H, 77H, 77H
    DB	0bcH, 77H, 0, 78H, 44H, 78H, 88H, 78H
    DB	0ccH, 78H, 10H, 79H, 53H, 79H, 97H, 79H
    DB	0daH, 79H, 1dH, 7aH, 60H, 7aH, 0a3H, 7aH
    DB	0e6H, 7aH, 29H, 7bH, 6bH, 7bH, 0adH, 7bH
    DB	0efH, 7bH, 32H, 7cH, 73H, 7cH, 0b5H, 7cH
    DB	0f7H, 7cH, 38H, 7dH, 7aH, 7dH, 0bbH, 7dH
    DB	0fcH, 7dH, 3dH, 7eH, 7eH, 7eH, 0beH, 7eH
    DB	0ffH, 7eH, 3fH, 7fH, 80H, 7fH, 0c0H, 7fH
    DB	0, 80H, 0, 0
_sf_tan_44100:
    DB	26H, 0, 0, 0, 27H, 0, 0, 0
    DB	28H, 0, 0, 0, 2aH, 0, 0, 0
    DB	2bH, 0, 0, 0, 2cH, 0, 0, 0
    DB	2dH, 0, 0, 0, 2fH, 0, 0, 0
    DB	30H, 0, 0, 0, 32H, 0, 0, 0
    DB	33H, 0, 0, 0, 34H, 0, 0, 0
    DB	36H, 0, 0, 0, 38H, 0, 0, 0
    DB	39H, 0, 0, 0, 3bH, 0, 0, 0
    DB	3dH, 0, 0, 0, 3eH, 0, 0, 0
    DB	40H, 0, 0, 0, 42H, 0, 0, 0
    DB	44H, 0, 0, 0, 46H, 0, 0, 0
    DB	48H, 0, 0, 0, 4aH, 0, 0, 0
    DB	4cH, 0, 0, 0, 4fH, 0, 0, 0
    DB	51H, 0, 0, 0, 53H, 0, 0, 0
    DB	56H, 0, 0, 0, 58H, 0, 0, 0
    DB	5bH, 0, 0, 0, 5dH, 0, 0, 0
    DB	60H, 0, 0, 0, 63H, 0, 0, 0
    DB	66H, 0, 0, 0, 69H, 0, 0, 0
    DB	6cH, 0, 0, 0, 6fH, 0, 0, 0
    DB	72H, 0, 0, 0, 76H, 0, 0, 0
    DB	79H, 0, 0, 0, 7dH, 0, 0, 0
    DB	80H, 0, 0, 0, 84H, 0, 0, 0
    DB	88H, 0, 0, 0, 8cH, 0, 0, 0
    DB	90H, 0, 0, 0, 94H, 0, 0, 0
    DB	99H, 0, 0, 0, 9dH, 0, 0, 0
    DB	0a2H, 0, 0, 0, 0a7H, 0, 0, 0
    DB	0abH, 0, 0, 0, 0b0H, 0, 0, 0
    DB	0b6H, 0, 0, 0, 0bbH, 0, 0, 0
    DB	0c0H, 0, 0, 0, 0c6H, 0, 0, 0
    DB	0ccH, 0, 0, 0, 0d2H, 0, 0, 0
    DB	0d8H, 0, 0, 0, 0deH, 0, 0, 0
    DB	0e5H, 0, 0, 0, 0ebH, 0, 0, 0
    DB	0f2H, 0, 0, 0, 0f9H, 0, 0, 0
    DB	1, 1, 0, 0, 8, 1, 0, 0
    DB	10H, 1, 0, 0, 18H, 1, 0, 0
    DB	20H, 1, 0, 0, 29H, 1, 0, 0
    DB	31H, 1, 0, 0, 3aH, 1, 0, 0
    DB	44H, 1, 0, 0, 4dH, 1, 0, 0
    DB	57H, 1, 0, 0, 61H, 1, 0, 0
    DB	6bH, 1, 0, 0, 76H, 1, 0, 0
    DB	81H, 1, 0, 0, 8cH, 1, 0, 0
    DB	98H, 1, 0, 0, 0a4H, 1, 0, 0
    DB	0b0H, 1, 0, 0, 0bdH, 1, 0, 0
    DB	0caH, 1, 0, 0, 0d7H, 1, 0, 0
    DB	0e5H, 1, 0, 0, 0f3H, 1, 0, 0
    DB	2, 2, 0, 0, 11H, 2, 0, 0
    DB	20H, 2, 0, 0, 30H, 2, 0, 0
    DB	40H, 2, 0, 0, 51H, 2, 0, 0
    DB	63H, 2, 0, 0, 75H, 2, 0, 0
    DB	87H, 2, 0, 0, 9aH, 2, 0, 0
    DB	0aeH, 2, 0, 0, 0c2H, 2, 0, 0
    DB	0d6H, 2, 0, 0, 0ecH, 2, 0, 0
    DB	2, 3, 0, 0, 18H, 3, 0, 0
    DB	2fH, 3, 0, 0, 47H, 3, 0, 0
    DB	60H, 3, 0, 0, 79H, 3, 0, 0
    DB	93H, 3, 0, 0, 0aeH, 3, 0, 0
    DB	0caH, 3, 0, 0, 0e6H, 3, 0, 0
    DB	3, 4, 0, 0, 21H, 4, 0, 0
    DB	40H, 4, 0, 0, 60H, 4, 0, 0
    DB	81H, 4, 0, 0, 0a3H, 4, 0, 0
    DB	0c6H, 4, 0, 0, 0e9H, 4, 0, 0
    DB	0eH, 5, 0, 0, 34H, 5, 0, 0
    DB	5bH, 5, 0, 0, 83H, 5, 0, 0
    DB	0adH, 5, 0, 0, 0d7H, 5, 0, 0
    DB	3, 6, 0, 0, 30H, 6, 0, 0
    DB	5fH, 6, 0, 0, 8fH, 6, 0, 0
    DB	0c0H, 6, 0, 0, 0f2H, 6, 0, 0
    DB	27H, 7, 0, 0, 5cH, 7, 0, 0
    DB	94H, 7, 0, 0, 0ccH, 7, 0, 0
    DB	7, 8, 0, 0, 43H, 8, 0, 0
    DB	81H, 8, 0, 0, 0c1H, 8, 0, 0
    DB	3, 9, 0, 0, 46H, 9, 0, 0
    DB	8cH, 9, 0, 0, 0d4H, 9, 0, 0
    DB	1eH, 0aH, 0, 0, 6aH, 0aH, 0, 0
    DB	0b8H, 0aH, 0, 0, 8, 0bH, 0, 0
    DB	5bH, 0bH, 0, 0, 0b0H, 0bH, 0, 0
    DB	8, 0cH, 0, 0, 63H, 0cH, 0, 0
    DB	0c0H, 0cH, 0, 0, 1fH, 0dH, 0, 0
    DB	82H, 0dH, 0, 0, 0e8H, 0dH, 0, 0
    DB	50H, 0eH, 0, 0, 0bcH, 0eH, 0, 0
    DB	2aH, 0fH, 0, 0, 9cH, 0fH, 0, 0
    DB	12H, 10H, 0, 0, 8bH, 10H, 0, 0
    DB	7, 11H, 0, 0, 87H, 11H, 0, 0
    DB	0bH, 12H, 0, 0, 93H, 12H, 0, 0
    DB	1fH, 13H, 0, 0, 0afH, 13H, 0, 0
    DB	43H, 14H, 0, 0, 0dcH, 14H, 0, 0
    DB	79H, 15H, 0, 0, 1bH, 16H, 0, 0
    DB	0c2H, 16H, 0, 0, 6dH, 17H, 0, 0
    DB	1eH, 18H, 0, 0, 0d4H, 18H, 0, 0
    DB	8fH, 19H, 0, 0, 51H, 1aH, 0, 0
    DB	17H, 1bH, 0, 0, 0e4H, 1bH, 0, 0
    DB	0b7H, 1cH, 0, 0, 90H, 1dH, 0, 0
    DB	70H, 1eH, 0, 0, 57H, 1fH, 0, 0
    DB	44H, 20H, 0, 0, 39H, 21H, 0, 0
    DB	35H, 22H, 0, 0, 39H, 23H, 0, 0
    DB	45H, 24H, 0, 0, 59H, 25H, 0, 0
    DB	75H, 26H, 0, 0, 9aH, 27H, 0, 0
    DB	0c8H, 28H, 0, 0, 0ffH, 29H, 0, 0
    DB	40H, 2bH, 0, 0, 8bH, 2cH, 0, 0
    DB	0e0H, 2dH, 0, 0, 40H, 2fH, 0, 0
    DB	0abH, 30H, 0, 0, 21H, 32H, 0, 0
    DB	0a3H, 33H, 0, 0, 31H, 35H, 0, 0
    DB	0ccH, 36H, 0, 0, 74H, 38H, 0, 0
    DB	2aH, 3aH, 0, 0, 0edH, 3bH, 0, 0
    DB	0c0H, 3dH, 0, 0, 0a2H, 3fH, 0, 0
    DB	93H, 41H, 0, 0, 96H, 43H, 0, 0
    DB	0a9H, 45H, 0, 0, 0ceH, 47H, 0, 0
    DB	6, 4aH, 0, 0, 51H, 4cH, 0, 0
    DB	0b0H, 4eH, 0, 0, 25H, 51H, 0, 0
    DB	0afH, 53H, 0, 0, 51H, 56H, 0, 0
    DB	0bH, 59H, 0, 0, 0deH, 5bH, 0, 0
    DB	0cbH, 5eH, 0, 0, 0d5H, 61H, 0, 0
    DB	0fbH, 64H, 0, 0, 41H, 68H, 0, 0
    DB	0a7H, 6bH, 0, 0, 2fH, 6fH, 0, 0
    DB	0dbH, 72H, 0, 0, 0adH, 76H, 0, 0
    DB	0a8H, 7aH, 0, 0, 0ceH, 7eH, 0, 0
    DB	21H, 83H, 0, 0, 0a5H, 87H, 0, 0
    DB	5dH, 8cH, 0, 0, 4bH, 91H, 0, 0
    DB	76H, 96H, 0, 0, 0dfH, 9bH, 0, 0
    DB	8dH, 0a1H, 0, 0, 85H, 0a7H, 0, 0
    DB	0ccH, 0adH, 0, 0, 69H, 0b4H, 0, 0
    DB	65H, 0bbH, 0, 0, 0c6H, 0c2H, 0, 0
    DB	97H, 0caH, 0, 0, 0e3H, 0d2H, 0, 0
    DB	0b7H, 0dbH, 0, 0, 1fH, 0e5H, 0, 0
    DB	2eH, 0efH, 0, 0, 0f6H, 0f9H, 0, 0
    DB	8dH, 5, 1, 0, 0fH, 12H, 1, 0
    DB	9aH, 1fH, 1, 0, 53H, 2eH, 1, 0
    DB	68H, 3eH, 1, 0, 0fH, 50H, 1, 0
    DB	8bH, 63H, 1, 0, 2fH, 79H, 1, 0
    DB	63H, 91H, 1, 0, 0adH, 0acH, 1, 0
    DB	0b8H, 0cbH, 1, 0, 67H, 0efH, 1, 0
    DB	0edH, 18H, 2, 0, 0efH, 49H, 2, 0
    DB	0c3H, 84H, 2, 0, 0d9H, 0ccH, 2, 0
    DB	70H, 27H, 3, 0, 3, 9dH, 3, 0
    DB	2bH, 3cH, 4, 0, 62H, 20H, 5, 0
    DB	4aH, 84H, 6, 0
_sf_tan_48000:
    DB	23H, 0, 0, 0, 24H, 0, 0, 0
    DB	25H, 0, 0, 0, 26H, 0, 0, 0
    DB	27H, 0, 0, 0, 29H, 0, 0, 0
    DB	2aH, 0, 0, 0, 2bH, 0, 0, 0
    DB	2cH, 0, 0, 0, 2dH, 0, 0, 0
    DB	2fH, 0, 0, 0, 30H, 0, 0, 0
    DB	32H, 0, 0, 0, 33H, 0, 0, 0
    DB	35H, 0, 0, 0, 36H, 0, 0, 0
    DB	38H, 0, 0, 0, 39H, 0, 0, 0
    DB	3bH, 0, 0, 0, 3dH, 0, 0, 0
    DB	3eH, 0, 0, 0, 40H, 0, 0, 0
    DB	42H, 0, 0, 0, 44H, 0, 0, 0
    DB	46H, 0, 0, 0, 48H, 0, 0, 0
    DB	4aH, 0, 0, 0, 4cH, 0, 0, 0
    DB	4fH, 0, 0, 0, 51H, 0, 0, 0
    DB	53H, 0, 0, 0, 56H, 0, 0, 0
    DB	58H, 0, 0, 0, 5bH, 0, 0, 0
    DB	5eH, 0, 0, 0, 60H, 0, 0, 0
    DB	63H, 0, 0, 0, 66H, 0, 0, 0
    DB	69H, 0, 0, 0, 6cH, 0, 0, 0
    DB	6fH, 0, 0, 0, 73H, 0, 0, 0
    DB	76H, 0, 0, 0, 79H, 0, 0, 0
    DB	7dH, 0, 0, 0, 81H, 0, 0, 0
    DB	84H, 0, 0, 0, 88H, 0, 0, 0
    DB	8cH, 0, 0, 0, 90H, 0, 0, 0
    DB	95H, 0, 0, 0, 99H, 0, 0, 0
    DB	9dH, 0, 0, 0, 0a2H, 0, 0, 0
    DB	0a7H, 0, 0, 0, 0acH, 0, 0, 0
    DB	0b1H, 0, 0, 0, 0b6H, 0, 0, 0
    DB	0bbH, 0, 0, 0, 0c1H, 0, 0, 0
    DB	0c6H, 0, 0, 0, 0ccH, 0, 0, 0
    DB	0d2H, 0, 0, 0, 0d8H, 0, 0, 0
    DB	0dfH, 0, 0, 0, 0e5H, 0, 0, 0
    DB	0ecH, 0, 0, 0, 0f3H, 0, 0, 0
    DB	0faH, 0, 0, 0, 1, 1, 0, 0
    DB	9, 1, 0, 0, 11H, 1, 0, 0
    DB	19H, 1, 0, 0, 21H, 1, 0, 0
    DB	29H, 1, 0, 0, 32H, 1, 0, 0
    DB	3bH, 1, 0, 0, 44H, 1, 0, 0
    DB	4eH, 1, 0, 0, 57H, 1, 0, 0
    DB	61H, 1, 0, 0, 6cH, 1, 0, 0
    DB	77H, 1, 0, 0, 81H, 1, 0, 0
    DB	8dH, 1, 0, 0, 98H, 1, 0, 0
    DB	0a4H, 1, 0, 0, 0b1H, 1, 0, 0
    DB	0bdH, 1, 0, 0, 0caH, 1, 0, 0
    DB	0d8H, 1, 0, 0, 0e6H, 1, 0, 0
    DB	0f4H, 1, 0, 0, 3, 2, 0, 0
    DB	12H, 2, 0, 0, 21H, 2, 0, 0
    DB	31H, 2, 0, 0, 42H, 2, 0, 0
    DB	52H, 2, 0, 0, 64H, 2, 0, 0
    DB	76H, 2, 0, 0, 88H, 2, 0, 0
    DB	9bH, 2, 0, 0, 0afH, 2, 0, 0
    DB	0c3H, 2, 0, 0, 0d8H, 2, 0, 0
    DB	0edH, 2, 0, 0, 3, 3, 0, 0
    DB	1aH, 3, 0, 0, 31H, 3, 0, 0
    DB	49H, 3, 0, 0, 61H, 3, 0, 0
    DB	7bH, 3, 0, 0, 95H, 3, 0, 0
    DB	0b0H, 3, 0, 0, 0cbH, 3, 0, 0
    DB	0e8H, 3, 0, 0, 5, 4, 0, 0
    DB	23H, 4, 0, 0, 42H, 4, 0, 0
    DB	62H, 4, 0, 0, 83H, 4, 0, 0
    DB	0a5H, 4, 0, 0, 0c8H, 4, 0, 0
    DB	0ecH, 4, 0, 0, 11H, 5, 0, 0
    DB	37H, 5, 0, 0, 5eH, 5, 0, 0
    DB	86H, 5, 0, 0, 0b0H, 5, 0, 0
    DB	0daH, 5, 0, 0, 6, 6, 0, 0
    DB	33H, 6, 0, 0, 62H, 6, 0, 0
    DB	92H, 6, 0, 0, 0c3H, 6, 0, 0
    DB	0f6H, 6, 0, 0, 2aH, 7, 0, 0
    DB	60H, 7, 0, 0, 97H, 7, 0, 0
    DB	0d0H, 7, 0, 0, 0bH, 8, 0, 0
    DB	47H, 8, 0, 0, 85H, 8, 0, 0
    DB	0c5H, 8, 0, 0, 7, 9, 0, 0
    DB	4bH, 9, 0, 0, 91H, 9, 0, 0
    DB	0d9H, 9, 0, 0, 22H, 0aH, 0, 0
    DB	6fH, 0aH, 0, 0, 0bdH, 0aH, 0, 0
    DB	0eH, 0bH, 0, 0, 61H, 0bH, 0, 0
    DB	0b6H, 0bH, 0, 0, 0eH, 0cH, 0, 0
    DB	69H, 0cH, 0, 0, 0c6H, 0cH, 0, 0
    DB	26H, 0dH, 0, 0, 89H, 0dH, 0, 0
    DB	0eeH, 0dH, 0, 0, 57H, 0eH, 0, 0
    DB	0c3H, 0eH, 0, 0, 32H, 0fH, 0, 0
    DB	0a4H, 0fH, 0, 0, 1aH, 10H, 0, 0
    DB	93H, 10H, 0, 0, 10H, 11H, 0, 0
    DB	90H, 11H, 0, 0, 14H, 12H, 0, 0
    DB	9cH, 12H, 0, 0, 28H, 13H, 0, 0
    DB	0b9H, 13H, 0, 0, 4dH, 14H, 0, 0
    DB	0e6H, 14H, 0, 0, 84H, 15H, 0, 0
    DB	26H, 16H, 0, 0, 0cdH, 16H, 0, 0
    DB	79H, 17H, 0, 0, 2aH, 18H, 0, 0
    DB	0e0H, 18H, 0, 0, 9cH, 19H, 0, 0
    DB	5dH, 1aH, 0, 0, 25H, 1bH, 0, 0
    DB	0f2H, 1bH, 0, 0, 0c5H, 1cH, 0, 0
    DB	9fH, 1dH, 0, 0, 7fH, 1eH, 0, 0
    DB	66H, 1fH, 0, 0, 54H, 20H, 0, 0
    DB	49H, 21H, 0, 0, 46H, 22H, 0, 0
    DB	4aH, 23H, 0, 0, 57H, 24H, 0, 0
    DB	6bH, 25H, 0, 0, 88H, 26H, 0, 0
    DB	0adH, 27H, 0, 0, 0dcH, 28H, 0, 0
    DB	14H, 2aH, 0, 0, 55H, 2bH, 0, 0
    DB	0a1H, 2cH, 0, 0, 0f7H, 2dH, 0, 0
    DB	57H, 2fH, 0, 0, 0c3H, 30H, 0, 0
    DB	3aH, 32H, 0, 0, 0bdH, 33H, 0, 0
    DB	4cH, 35H, 0, 0, 0e7H, 36H, 0, 0
    DB	90H, 38H, 0, 0, 47H, 3aH, 0, 0
    DB	0cH, 3cH, 0, 0, 0dfH, 3dH, 0, 0
    DB	0c2H, 3fH, 0, 0, 0b5H, 41H, 0, 0
    DB	0b8H, 43H, 0, 0, 0ccH, 45H, 0, 0
    DB	0f3H, 47H, 0, 0, 2cH, 4aH, 0, 0
    DB	78H, 4cH, 0, 0, 0d9H, 4eH, 0, 0
    DB	4fH, 51H, 0, 0, 0dbH, 53H, 0, 0
    DB	7eH, 56H, 0, 0, 39H, 59H, 0, 0
    DB	0eH, 5cH, 0, 0, 0feH, 5eH, 0, 0
    DB	9, 62H, 0, 0, 31H, 65H, 0, 0
    DB	79H, 68H, 0, 0, 0e1H, 6bH, 0, 0
    DB	6bH, 6fH, 0, 0, 1aH, 73H, 0, 0
    DB	0efH, 76H, 0, 0, 0edH, 7aH, 0, 0
    DB	15H, 7fH, 0, 0, 6cH, 83H, 0, 0
    DB	0f3H, 87H, 0, 0, 0aeH, 8cH, 0, 0
    DB	0a1H, 91H, 0, 0, 0cfH, 96H, 0, 0
    DB	3dH, 9cH, 0, 0, 0efH, 0a1H, 0, 0
    DB	0ecH, 0a7H, 0, 0, 39H, 0aeH, 0, 0
    DB	0dcH, 0b4H, 0, 0, 0deH, 0bbH, 0, 0
    DB	46H, 0c3H, 0, 0, 1fH, 0cbH, 0, 0
    DB	74H, 0d3H, 0, 0, 50H, 0dcH, 0, 0
    DB	0c3H, 0e5H, 0, 0, 0deH, 0efH, 0, 0
    DB	0b3H, 0faH, 0, 0, 59H, 6, 1, 0
    DB	0ebH, 12H, 1, 0, 88H, 20H, 1, 0
    DB	57H, 2fH, 1, 0, 85H, 3fH, 1, 0
    DB	49H, 51H, 1, 0, 0e6H, 64H, 1, 0
    DB	0b2H, 7aH, 1, 0, 15H, 93H, 1, 0
    DB	99H, 0aeH, 1, 0, 0eaH, 0cdH, 1, 0
    DB	0f2H, 0f1H, 1, 0, 0e7H, 1bH, 2, 0
    DB	7aH, 4dH, 2, 0, 0fH, 89H, 2, 0
    DB	2cH, 0d2H, 2, 0, 3cH, 2eH, 3, 0
    DB	1, 0a6H, 3, 0

CONST2		ENDS
_DATA		SEGMENT	WORD PUBLIC USE16 'DATA'
_sf_headroom_gain:
    DB	0, 80H
_sf_rate:
    DB	44H, 0acH

_DATA		ENDS
_BSS		SEGMENT	PARA PUBLIC USE16 'BSS'
    ORG 0
_irq_stack    LABEL	BYTE
    ORG 2000H
_sf_voices    LABEL	BYTE
    ORG 5b00H
_sf_mix    LABEL	BYTE
    ORG 6b00H
_sf_channels    LABEL	BYTE
    ORG 6da0H
_sf_bank    LABEL	BYTE
    ORG 6db0H
_request_data    LABEL	BYTE
    ORG 6db4H
_sf_serial    LABEL	BYTE
    ORG 6db8H
_request_value    LABEL	BYTE
    ORG 6dbaH
_saved_sp    LABEL	BYTE
    ORG 6dbcH
_saved_ss    LABEL	BYTE
    ORG 6dbeH
_request_command    LABEL	BYTE
    ORG 6dc0H
_request_result    LABEL	BYTE
    ORG 6dc2H
_sf_tan_values    LABEL	BYTE
    ORG 6dc4H
_sf_quick_release    LABEL	BYTE
    ORG 6dc6H
_sf_output_gain    LABEL	BYTE
    ORG 6dc8H
_sf_limit    LABEL	BYTE
    ORG 6dcaH
_sf_ready    LABEL	BYTE
    ORG 6dccH
_sf_mode    LABEL	BYTE
    ORG 6dceH
_BSS		ENDS

		END
