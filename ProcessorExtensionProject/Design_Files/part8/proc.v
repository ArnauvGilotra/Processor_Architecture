module proc(DIN, Resetn, Clock, Run, DOUT, ADDR, W);
    input [15:0] DIN;
    input Resetn, Clock, Run;
    output wire [15:0] DOUT;
    output wire [15:0] ADDR;
    output wire W;

    wire [0:7] R_in; // r0, ..., r7 register enables
    reg rX_in, IR_in, ADDR_in, Done, DOUT_in, A_in, G_in, AddSub, ALU_and;
    reg [2:0] Tstep_Q, Tstep_D;
    reg [15:0] BusWires;
    reg [3:0] Select; // BusWires selector
    reg [15:0] Sum;
    wire [2:0] III, rX, rY; // instruction opcode and register operands
    wire [15:0] r0, r1, r2, r3, r4, r5, r6, pc, A, rF;
    wire [15:0] G;
    wire [15:0] IR;
    wire cF, nF, zF;
    reg pc_incr;    // used to increment the pc
    reg sp_incr;    // used to increment the sp
    reg sp_dec;    // used to decrement the sp
    reg pc_in;      // used to load the pc
    reg sp_in;      // used to sp
    reg W_D;        // used for write signal
    reg cout;
    reg [15:0] FlagWires;
    wire Imm;
    reg F_in;       // enables the Flag register
    reg lr_in;      // enables the lr register (r6)
    reg do_shift;   // enables shifting
   
    assign III = IR[15:13];
    assign Imm = IR[12];
    assign rX = IR[11:9];
    assign rY = IR[2:0];

    //set up flags
    assign cF = rF[2];
    assign nF = rF[1];
    assign zF = rF[0];

    wire shift_flag;
    wire [1:0] shift_type;
    
    wire shift_Imm_Data;

    assign shift_flag = IR[8]; //To differentiate between cmp rX,rY and the shift/rotate instructions
                               //it is sufficient to examine the digit in bit-position 8.
    assign shift_type = IR[6:5]; //Op2 is #D encode them as 1110XXX11SS0DDDD. In these encodings SS specifies the type of shift/ro-
                                 //tate, where SS = 00 (lsl), 01 (lsr), 10 (asr), or 11 (ror)
     
    assign shift_Imm_Data = IR[7]; // Are we shifting by immediate data or by a value inside the reg rY

    wire [15:0] shift_result;
    wire [3:0] DIN_b;

    dec3to8 decX (rX_in, rX, R_in); // produce r0 - r7 register enables

    parameter T0 = 3'b000, T1 = 3'b001, T2 = 3'b010, T3 = 3'b011, T4 = 3'b100, T5 = 3'b101;

    // Control FSM state tables
    always @(Tstep_Q, Run, Done)
        case (Tstep_Q)
            T0: // instruction fetch
                if (~Run) Tstep_D = T0;
                else Tstep_D = T1;
            T1: // wait cycle for synchronous memory
                Tstep_D = T2;
            T2: // this time step stores the instruction word in IR
                Tstep_D = T3;
            T3: if (Done) Tstep_D = T0;
                else Tstep_D = T4;
            T4: if (Done) Tstep_D = T0;
                else Tstep_D = T5;
            T5: // instructions end after this time step
                Tstep_D = T0;
            default: Tstep_D = 3'bxxx;
        endcase

    /* OPCODE format: III M XXX DDDDDDDDD, where 
    *     III = instruction, M = Immediate, XXX = rX. If M = 0, DDDDDDDDD = 000000YYY = rY
    *     If M = 1, DDDDDDDDD = #D is the immediate operand 
    *
    *  III M  Instruction   Description
    *  --- -  -----------   -----------
    *  000 0: mv   rX,rY    rX <- rY
    *  000 1: mv   rX,#D    rX <- D (sign extended)
    *  001 1: mvt  rX,#D    rX <- D << 8
    *  010 0: add  rX,rY    rX <- rX + rY
    *  010 1: add  rX,#D    rX <- rX + D
    *  011 0: sub  rX,rY    rX <- rX - rY
    *  011 1: sub  rX,#D    rX <- rX - D
    *  100 0: ld   rX,[rY]  rX <- [rY]
    *  101 0: st   rX,[rY]  [rY] <- rX
    *  110 0: and  rX,rY    rX <- rX & rY
    *  110 1: and  rX,#D    rX <- rX & D */
    parameter mv = 3'b000, mvt = 3'b001, add = 3'b010, sub = 3'b011, ld = 3'b100, st = 3'b101,
	     and_ = 3'b110, cs = 3'b111;
    // selectors for the BusWires multiplexer
    parameter _R0 = 4'b0000, _R1 = 4'b0001, _R2 = 4'b0010, _R3 = 4'b0011, _R4 = 4'b0100,
        _R5 = 4'b0101, _R6 = 4'b0110, _PC = 4'b0111, _G = 4'b1000, 
        _IR8_IR8_0 /* signed-extended immediate data */ = 4'b1001, 
        _IR7_0_0 /* immediate data << 8 */ = 4'b1010,
        _DIN /* data-in from memory */ = 4'b1011,
		_0_IR3_0 = 4'b1100;
    
    parameter B = 3'b0, BEQ = 3'b001, BNE = 3'b010, BCC = 3'b011, BCS = 3'b100, BPL = 3'b101, 
            BMI = 3'b110, BL = 3'b111; 

    // Control FSM outputs
    always @(*) begin
        // default values for control signals
        rX_in = 1'b0; A_in = 1'b0; G_in = 1'b0; IR_in = 1'b0; DOUT_in = 1'b0; ADDR_in = 1'b0; 
        Select = 4'bxxxx; AddSub = 1'b0; ALU_and = 1'b0; W_D = 1'b0; Done = 1'b0;
        pc_in = R_in[7] /* default pc enable */; pc_incr = 1'b0; do_shift = 1'b0;
        F_in = 1'b0; sp_in = R_in[5]; sp_incr = 1'b0; sp_dec = 1'b0; lr_in = R_in[6]; 
        case (Tstep_Q)
            T0: begin // fetch the instruction
                Select = _PC;  // put pc onto the internal bus
                ADDR_in = 1'b1;
                pc_incr = Run; // to increment pc
            end
            T1: // wait cycle for synchronous memory
                ;
            T2: // store instruction on DIN in IR 
                IR_in = 1'b1;
            T3: // define signals in T3
                case (III)
                    mv: begin
                        if (!Imm) Select = rY;          // mv rX, rY
                        else Select = _IR8_IR8_0; // mv rX, #D
                        rX_in = 1'b1;                   // enable the rX register
                        Done = 1'b1;
                    end
                    mvt: begin
                        case (Imm)
                            1'b1: begin
                                Select = _IR7_0_0;
                                rX_in = 1'b1;
                                Done = 1'b1;
                            end
                            1'b0: begin
                                Select = _PC;
                                A_in = 1'b1;
                                if (rX == BL) lr_in = 1'b1;
                            end
                        endcase

                    end
                    add, sub, and_: begin
                        // ... your code goes here
                        Select = rX;
                        A_in = 1'b1;
                    end
                    ld: begin
                        // ... your code goes here
                        Select = rY;
                        ADDR_in = 1'b1;
                        sp_incr = (Imm) ? 1'b1: 1'b0; //pop requires sp is increamented as the stack grows from higher address to lower
                    end
                    st: begin
                        // ... your code goes here
                        case (Imm)
                            1'b0: begin
                                Select = rY;
                                ADDR_in = 1'b1;
                            end
                            1'b1: begin
                                sp_dec = 1'b1; //push requires sp be decreamented as the stack grows from higher address to lower
                            end
                            default: ;
                        endcase
                    end
                    cs: begin
                        // ... your code goes here
                        Select = rX;
                        A_in = 1'b1;
                    end
                    default: ;
                endcase
            T4: // define signals T2
                case (III)
                    mvt: begin
                        // ... my code goes here
                        Select = _IR8_IR8_0;
                        G_in = 1'b1;
                    end
                    add: begin
                        // ... your code goes here
                        Select = Imm ? _IR8_IR8_0 : rY;
                        AddSub = 1'b0;
                        G_in = 1'b1;
						F_in = 1'b1;
                    end
                    sub: begin
                        // ... your code goes here
                        Select = Imm ? _IR8_IR8_0 : rY;
                        AddSub = 1'b1;
                        G_in = 1'b1;
						F_in = 1'b1;
                    end
                    and_: begin
                        // ... your code goes here
                        Select = Imm ? _IR8_IR8_0 : rY;
                        ALU_and = 1'b1;
                        G_in = 1'b1;
						F_in = 1'b1;
                    end
                    ld: // wait cycle for synchronous memory
                        ;
                    st: begin
                        // ... your code goes here
                        case (Imm)
                            1'b0: begin
                                Select = rX;
                                DOUT_in = 1'b1;
                                W_D = 1'b1;
                                Done = 1'b1; //can make it done here even though it will take another clock cycle as it doesnt matter to us
                            end 
                            1'b1: begin
                                Select = rY;
                                ADDR_in = 1'b1;
                            end
                            default: ;
                        endcase 
                    end
                    cs: begin
                        F_in = 1'b1;
                        case (shift_flag)
                            1'b0: begin //cmp instruction
                                case (Imm)
                                    1'b0: begin
                                        Select = rY;
                                        AddSub = 1'b1; // Doing the subtraction here would lead the ALU to subtract and update the flags
                                        Done = 1'b1; //cmp is done here. we do not need to update any destination register
                                    end
                                    1'b1: begin
                                        Select = _IR8_IR8_0;
                                        AddSub = 1'b1; // Doing the subtraction here would lead the ALU to subtract and update the flags
                                        Done = 1'b1; //cmp is done here. we do not need to update any destination register
                                    end
                                    default: ;
                                endcase
                            end
                            1'b1: begin //some shift instruction
                                case (Imm)
                                    1'b0: begin
                                        Select = (shift_Imm_Data) ? _0_IR3_0 : rY; //either get the rY val or the 3-0 bits value extendented with 0s
                                        do_shift = 1'b1;
                                        G_in = 1'b1; 
                                    end
                                    1'b1: begin
                                        Select = _IR8_IR8_0;
                                        AddSub = 1'b1; // Doing the subtraction here would lead the ALU to subtract and update the flags
                                        Done = 1'b1; //cmp is done here. we do not need to update any destination register
                                    end    
                                    default: ;
                                endcase
                            end
                            default: ;
                        endcase
                    end
                    default: ; 
                endcase
            T5: // define T3
                case (III)
                    mvt: begin
                        // .. my code goes here
                        Select = _G;
                        case (rX)
                            B: pc_in = 1'b1;
                            BL: pc_in = 1'b1;
                            BEQ: if (zF) begin
                                pc_in = 1'b1;
                            end
                            BNE: if (!zF) begin
                                pc_in = 1'b1;
                            end
                            BCC: if (!cF) begin
                                pc_in = 1'b1;
                            end
                            BCS: if (cF) begin
                                pc_in = 1'b1;
                            end
                            BPL: if (!nF) begin
                                pc_in = 1'b1;
                            end
                            BMI: if (nF) begin
                                pc_in = 1'b1;
                            end
                            default: ;
                        endcase
                        Done = 1'b1;
                    end
                    add, sub, and_: begin
                        // ... your code goes here
                        Select = _G;
                        rX_in = 1'b1;
						Done = 1'b1;
                    end
                    ld: begin
                        // ... your code goes here
                        Select = _DIN;
                        rX_in = 1'b1;
						Done = 1'b1;
                    end
                    st: begin
                        if (Imm) begin 
                            Select = rX;
                            DOUT_in = 1'b1;
                            W_D = 1'b1;
                        end
                        Done = 1'b1;
                    end
                    cs: begin
                        Select = _G;
                        rX_in = 1'b1;
                        Done = 1'b1;
                    end
                    default: ;
                endcase
            default: ;
        endcase
    end   
   
    // Control FSM flip-flops
    always @(posedge Clock)
        if (!Resetn)
            Tstep_Q <= T0;
        else
            Tstep_Q <= Tstep_D;   
   
    regn reg_0 (BusWires, Resetn, R_in[0], Clock, r0);
    regn reg_1 (BusWires, Resetn, R_in[1], Clock, r1);
    regn reg_2 (BusWires, Resetn, R_in[2], Clock, r2);
    regn reg_3 (BusWires, Resetn, R_in[3], Clock, r3);
    regn reg_4 (BusWires, Resetn, R_in[4], Clock, r4);

    // r7 is program counter
    // module pc_count(R, Resetn, Clock, E, L, Q);
    pc_count reg_pc (BusWires, Resetn, Clock, pc_incr, pc_in, pc);

    //Change R6, R5 into the LR and SP
    // r6 is the link register
    regn reg_6 (BusWires, Resetn, lr_in, Clock, r6);

    // r5 is the stack pointer register
    //module sp_count(R, Resetn, Clock, U, D, L, Q);
    sp_count reg_SP (BusWires, Resetn, Clock, sp_incr, sp_dec, sp_in, r5);

    regn reg_F (FlagWires, Resetn, F_in, Clock, rF);

    regn reg_A (BusWires, Resetn, A_in, Clock, A);
    regn reg_DOUT (BusWires, Resetn, DOUT_in, Clock, DOUT);
    regn reg_ADDR (BusWires, Resetn, ADDR_in, Clock, ADDR);
    regn reg_IR (DIN, Resetn, IR_in, Clock, IR);

    flipflop reg_W (W_D, Resetn, Clock, W);
    
    // alu
    always @(*)
        begin
		FlagWires = 3'b0;

		if (do_shift)
            Sum = shift_result;
		else if (!ALU_and)
            if (!AddSub)
                {cout, Sum} = A + BusWires;
            else
                {cout, Sum} = A + ~BusWires + 16'b1;
		else
            {cout, Sum} = A & BusWires;
		
		if (cout) FlagWires[2] = 1'b1;
		if (Sum[15] == 1'b1) FlagWires[1] = 1'b1;
		if (Sum == 0) FlagWires[0] = 1'b1;
	end
    
    regn reg_G (Sum, Resetn, G_in, Clock, G);

    assign DIN_b = BusWires[3:0]; //shift is only a 4 bit value
    barrel shifter (shift_type, DIN_b, A, shift_result);

    // define the internal processor bus
    always @(*)
        case (Select)
            _R0: BusWires = r0;
            _R1: BusWires = r1;
            _R2: BusWires = r2;
            _R3: BusWires = r3;
            _R4: BusWires = r4;
            _R5: BusWires = r5;
            _R6: BusWires = r6;
            _PC: BusWires = pc;
            _G: BusWires = G;
            _IR8_IR8_0: BusWires = {{7{IR[8]}}, IR[8:0]}; // sign extended
            _IR7_0_0: BusWires = {IR[7:0], 8'b0};
            _DIN: BusWires = DIN;
            _0_IR3_0: BusWires = {12'b0, IR[3:0]}; // immediate data for shift
            default: BusWires = 16'bx;
        endcase
endmodule

module pc_count(R, Resetn, Clock, E, L, Q);
    input [15:0] R;
    input Resetn, Clock, E, L;
    output [15:0] Q;
    reg [15:0] Q;
   
    always @(posedge Clock)
        if (!Resetn)
            Q <= 16'b0;
        else if (L)
            Q <= R;
        else if (E)
            Q <= Q + 1'b1;
endmodule

// Pretty much the same as pc_count but it can decreament if D = 1. (As per the handout diagram of the CPU)
module sp_count(R, Resetn, Clock, U, D, L, Q);
    input [15:0] R;
    input Resetn, Clock, U, D, L;
    output [15:0] Q;
    reg [15:0] Q;
   
    always @(posedge Clock)
        if (!Resetn)
            Q <= 16'b0;
        else if (L)
            Q <= R;
        else if (U)
            Q <= Q + 1'b1;
		else if (D)
			Q <= Q - 1'b1;
endmodule

module dec3to8(E, W, Y);
    input E; // enable
    input [2:0] W;
    output [0:7] Y;
    reg [0:7] Y;
   
    always @(*)
        if (E == 0)
            Y = 8'b00000000;
        else
            case (W)
                3'b000: Y = 8'b10000000;
                3'b001: Y = 8'b01000000;
                3'b010: Y = 8'b00100000;
                3'b011: Y = 8'b00010000;
                3'b100: Y = 8'b00001000;
                3'b101: Y = 8'b00000100;
                3'b110: Y = 8'b00000010;
                3'b111: Y = 8'b00000001;
            endcase
endmodule

module regn(R, Resetn, E, Clock, Q);
    parameter n = 16;
    input [n-1:0] R;
    input Resetn, E, Clock;
    output [n-1:0] Q;
    reg [n-1:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 0;
        else if (E)
            Q <= R;
endmodule

// from handout: the barrel shifter code 
// This module specifies a barrel shifter that can perform lsl, lsr, asr, and ror
module barrel (shift_type, shift, data_in, data_out);
    input wire [1:0] shift_type;
    input wire [3:0] shift;
    input wire [15:0] data_in;
    output reg [15:0] data_out;

    parameter lsl = 2'b00, lsr = 2'b01, asr = 2'b10, ror = 2'b11;

    always @(*)
        if (shift_type == lsl)
            data_out = data_in << shift;
        else if (shift_type == lsr) 
            data_out = data_in >> shift;
        else if (shift_type == asr) 
            data_out = {{16{data_in[15]}},data_in} >> shift;    // sign extend
        else // ror
            data_out = (data_in >> shift) | (data_in << (16 - shift));
endmodule