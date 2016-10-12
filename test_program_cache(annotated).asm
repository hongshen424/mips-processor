addi $t0, $0, 500			;0x000		t0 = 500
addi $t1, $0, 400			;0x004
addi $t2, $0, 300			;0x008
addi $t3, $0, 700			;0x00c
add $t4, $t2, $t1			;0x010		t4 = 700
bne $t4, $t3, done1			;0x014		don't branch
sub $t3, $t0, $t2			;0x018		t3 = 200
addi $t2, $0, 305			;0x01c		t2 = 305
mult $t2, $t3				;0x020		hi,lo = {0x0000, 0xEE48}
mfhi $t4				;0x024		t4 = 0x0000
mflo $t5				;0x028		t5 = 0xEE48
done1:

addi $t1, $0, 176			;0x02c		t1 = 176 	0xB0
addi $t2, $0, 151			;0x030		t2 = 151 	0x97
lui $t3, 3				;0x034		t3 = 		0x30000
addi $t4, $0, 211			;0x038		t4 = 211 	0xD3
							;t5 = 		0xEE48


							;						WITH ONE WAY
sw $t1, 0x0034($0)			;0x03c		write miss into 	way A			write miss
sw $t1, 0x0070($t3)			;0x040		write miss into 	way A			write miss
sw $t2, 0x003C($0)			;0x044		write hit 		way A			write hit
sw $t2, 0x4070($t3)			;0x048		write miss into		way B			write miss
sw $t3, 0x4038($0)			;0x04c		write miss into 	way B			write miss
lw $t5, 0x0034($0) 			;0x050		read hit from		way A			read  hit
sw $t3, 0x0074($t3)			;0x054		write hit into		way A			write hit
sw $t4, 0xC030($0)	;0x4030		0x058		write miss into way ? (+evict)			write miss
sw $t4, 0x807C($t3)	;0x007C		0x05c		write miss into way ? (+evict)			write miss
sw $t2, 0xC078($t3)	;0x4078		0x060		write miss into way ? (+evict)			write miss
lw $t5, 0x4038($0)	;		0x064								read  hit
sw $t2, 0xC078($t3)	;0x4078		0x068								write hit
lw $t5, 0x0074($t3)	;		0x06c								read  hit
lw $t5, 0x0070($t3)	;		0x070								read  hit
lw $t5, 0x0034($0)	;		0x074								read  hit
lw $t5, 0xC078($t3)	;0x4078		0x078								read  hit
lw $t5, 0x807C($t3)	;0x007C		0x07c								read  hit
lw $t5, 0x003C($0)	;		0x080								read  hit
lw $t5, 0x0070($t3)	;		0x084								read  hit
sw $t5, 0x8070($t3)	;0x0070		0x088								write hit
lw $t5, 0xC030($0)	;0x4030		0x08c								read  hit