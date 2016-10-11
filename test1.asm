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
