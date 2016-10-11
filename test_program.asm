addi $s0, $zero, 5
addi $s1, $zero, 10
addi $s2, $zero, 15
addi $s3, $zero, 20
addi $s4, $zero, 25
addi $s5, $zero, 30
addi $s6, $zero, 35
addi $s7, $zero, 40

add $t0, $s0, $s1  #t0 = 15
add $t1, $t0, $s7  #t1 = 55
add $t2, $t0, $t1  #t2 = 70
add $t3, $t2, $t1  #t3 = 125

beq $s2, $t0, branch1
addi $t6, $zero, 999999

branch1:

addi $t4, $zero, 62
beq $s0, $s1, not_taken

beq $s2, $t0, taken
not_taken:
addi $t6, $zero, 999999
taken:

addi $t5, $zero, 65