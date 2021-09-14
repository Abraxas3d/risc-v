\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   m4_asm(ADD, x14, x13, x14)           // Incremental summation
   m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // Test result value in x14, and set x31 to reflect pass/fail.
   //Add instruction after the branch that writes a non-zero value to x0
   m4_asm(ADDI, x0, x0, 1111)           // Store contents of x0 plus 1111 in x0
   m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   m4_asm_end()
   m4_define(['M4_MAX_CYC'], 50)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   
   // YOUR CODE HERE
   // ...
   
   //program counter
   $next_pc[31:0] =
      $reset ? 32'b0 :
      $taken_br ? $br_tgt_pc[31:0] :
      $pc[31:0] + 4;
   
   $pc[31:0] = >>1$next_pc[31:0];
   
   
   //`READONLY_MEM($addr, $$read_data[31:0]);  
   //implement this macro providing $pc as the address and $$instr[31:0] as the output. 
   
   `READONLY_MEM($pc, $$instr[31:0]);
   
   
   
   //decode the instruction type
   $is_u_instr = $instr[6:2] == 5'b00101 || $instr[6:2] == 5'b01101;
   $is_i_instr = $instr[6:2] == 5'b11001 || ($instr[6:5] == 2'b00 && ($instr[4:2] == 3'b000 || $instr[4:2] == 3'b001 || $instr[4:2] == 3'b100 || $instr[4:2] == 3'b110));
   $is_r_instr = $instr[6:2] == 5'b10100 || ($instr[6:5] == 2'b01 && ($instr[4:2] == 3'b011 || $instr[4:2] == 3'b100 || $instr[4:2] == 3'b110));
   $is_s_instr = $instr[6:2] == 5'b01000 || $instr[6:2] == 5'b01001;
   $is_b_instr = $instr[6:2] == 5'b11000;
   $is_j_instr = $instr[6:2] == 5'b11011;
   
   
   //Decode Logic: Instruction Fields
   $funct3[2:0] = $instr[14:12];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   $rd[4:0] = $instr[11:7];
   $opcode[6:0] = $instr[6:0];
  
   //construct the immediate field 
   $imm[31:0] = $is_i_instr ? {  {21{$instr[31]}},  $instr[30:20]  } :
                $is_s_instr ? {  {21{$instr[31]}},  $instr[30:25], $instr[11:7]  } :
                $is_b_instr ? {  {20{$instr[31]}},  $instr[7],  $instr[30:25],   $instr[11:8], 1'b0   } :
                $is_u_instr ? {  $instr[31:12],     {12{1'b0}}  }:
                $is_j_instr ? {  {12{$instr[31]}},  $instr[19:12], $instr[20], $instr[30:21], 1'b0   } :
                              32'b0;  // Default
  
  
  
  
   //Decode Logic: are the fields valid?
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
   $opcode_valid[0] = 1'b1; //always valid
   $imm_valid = $is_u_instr || $is_i_instr || $is_s_instr || $is_b_instr || $is_j_instr;
   
   
   //determine specific instruction
   
   //for convenience second highest bit, 3 bits funct3, 6 bits opcode
   $dec_bits[10:0] = {$instr[30],$funct3,$opcode};
   
   
   
   //identify an instruction (example from lecture, x means 'do not care')
   $is_beq = $dec_bits ==? 11'bx_000_1100011; //test passes, then $is_beq is true
   
   //we implement the rest of them 
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add = $dec_bits ==? 11'b0_000_0110011;
   
   //turn off the warnings about dangling stuff
   `BOGUS_USE($rd $rd_valid $rs1 $rs1_valid $rs2 $rs2_valid 
      $funct3 $funct3_valid $imm_valid $opcode $opcode_valid $imm
      $is_bne $is_blt $is_bge $is_bltu $is_bgeu $is_addi $is_add
      $is_beq) 
      
   //Arithmetic Logic Unit
   //Register File Read
   //there's an error in the drawing from the classwork
   //implement ADDI and ADD
   //ADDI is add immediate to @src1_value
   //ADD is add @src1_value and @src2_value
   $result[31:0] = 
      $is_addi ? $src1_value + $imm :
      $is_add ? $src1_value + $src2_value :  
      32'b0;
   
   //Register File Write
   
   //modify logic to deassert the register file write enable input ($rd_valid) if $rd = 0. 
   $rd_valid = ($rd == 5'b00000) ? 1'b0 : $rd_valid;
   
   //if the instruction has a valid destination register ($rd_valid), 
   //then write $result to register file. Otherwise, $result[31:0] is set to zero. 
   $result[31:0] = 
      $rd_valid ? $result :
      32'b0;
      
      
   //Branch Logic
   $taken_br = 
      $is_beq ? ($src1_value == $src2_value) :
      $is_bne ? ($src1_value != $src2_value) :
      $is_blt ? ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
      $is_bge ? ($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
      $is_bltu ? ($src1_value < $src2_value) :
      $is_bgeu ? ($src1_value >= $src2_value) :
      1'b0;
      
   //target program counter (from a branch) is the PC of the branch plus its immediate value 
   $br_tgt_pc[31:0] = $pc[31:0] + $imm[31:0];
   
   //if the instruction is a taken branch, it's next PC should be the target branch PC. 
   //update the existing $next_pc expression to reflect this. 
   
      
   // Assert these to end simulation (before Makerchip cycle limit).
   //*passed = 1'b0; //original line
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   //register file instantiation M4 macro. Original line first, modified line second.
   //m4+rf(32, 32, $reset, $wr_en, $wr_index[4:0], $wr_data[31:0], $rd1_en, $rd1_index[4:0], $rd1_data, $rd2_en, $rd2_index[4:0], $rd2_data)
   m4+rf(32, 32, $reset, $rd_valid, $rd[4:0], $result[31:0], $rs1_valid, $rs1[4:0], $src1_value, $rs2_valid, $rs2[4:0], $src2_value)
   
   
   //m4+dmem(32, 32, $reset, $addr[4:0], $wr_en, $wr_data[31:0], $rd_en, $rd_data)
   m4+cpu_viz()
\SV
   endmodule
