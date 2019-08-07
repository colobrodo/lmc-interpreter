%%%% -*- Mode: Prolog -*-

%%%% Cologni Davide Matricola 830177
%%%% Cestari Davide Matricola 829626
%%%% Bertolotti Giorgio Matricola 829613

access_register(PC, Mem, Content) :-
    Address is mod(PC, 100),
    nth0(Address, Mem, Content).

set_flag(P, flag) :-
    P, !.
set_flag(_, noflag).


% Add 1xx
run_instruction(1,
		XX,
		state(Acc, PC, Mem, In, Out, _),
		state(NewAcc, NextPC, Mem, In, Out, NewFlag)) :-
    access_register(XX, Mem, N),
    NewAcc is mod(N + Acc, 1000),
    set_flag(N + Acc >= 1000, NewFlag),
    NextPC is PC + 1.

% Sub 2xx
run_instruction(2,
		XX,
		state(Acc, PC, Mem, In, Out, _),
		state(NewAcc, NextPC, Mem, In, Out, NewFlag)) :-
    access_register(XX, Mem, N),
    NewAcc is mod(Acc - N, 1000),
    set_flag(Acc - N < 0, NewFlag),
    NextPC is PC + 1.

% Store 3xx STA
run_instruction(3,
		XX,
		state(Acc, PC, Mem, In, Out, Flag),
		state(Acc, NextPC, NewMem, In, Out, Flag)) :-
	nth0(XX, Mem, _, Rest),
	nth0(XX, NewMem, Acc, Rest),
	NextPC is PC + 1.

% Load 5xx LDA
run_instruction(5,
		XX,
		state(_, PC, Mem, In, Out, Flag),
		state(CellContent, NextPC, Mem, In, Out, Flag)) :-
    access_register(XX, Mem, CellContent),
    NextPC is PC + 1.

% Branch 6xx BRA, Salto non condizionale
run_instruction(6,
		XX,
		state(Acc, _, Mem, In, Out, Flag),
		state(Acc, XX, Mem, In, Out, Flag)).

% Branch if zero 7xx BRZ,
% Salto condizionale se flag è assente (noflag) e accumulatore a 0
run_instruction(7,
		XX,
		state(0, _, Mem, In, Out, noflag),
		state(0, XX, Mem, In, Out, noflag)) :- !. 

run_instruction(7,
		_,
		state(Acc, PC, Mem, In, Out, Flag),
		state(Acc, NextPC, Mem, In, Out, Flag)) :-
    Acc \= 0,
    NextPC is PC + 1.

run_instruction(7,
		_,
		state(Acc, PC, Mem, In, Out, flag),
		state(Acc, NextPC, Mem, In, Out, flag)) :-
    NextPC is PC + 1.

% Branch if positive 8xx BRP,
% Salto condizionale se flag è assente (noflag)
run_instruction(8,
		XX,
		state(Acc, _, Mem, In, Out, noflag),
		state(Acc, XX, Mem, In, Out, noflag)).

run_instruction(8,
		_,
		state(Acc, PC, Mem, In, Out, flag),
		state(Acc, NextPC, Mem, In, Out, flag)) :-
    NextPC is PC + 1.

% Halt 0xx HLT, termine del programma
run_instruction(0,
		_,
		state(Acc, PC, Mem, In, Out, Flag),
		halted_state(Acc, PC, Mem, In, Out, Flag)).

% Input 901 INP
run_instruction(9,
                1,
                state(_, PC, Mem, [Head | NewIn], Out, Flag),
                state(Head, NextPC, Mem, NewIn, Out, Flag)) :-
    NextPC is PC + 1.


% Output 902 OUT
run_instruction(9,
                2,
                state(Acc, PC, Mem, In, Out, Flag),
                state(Acc, NextPC, Mem, In, NewOut, Flag)) :-
    append(Out, [Acc], NewOut),
    NextPC is PC + 1.

fetch_instruction(state(_, PC, Mem, _, _, _),
		  Code,
		  Argument) :-
    access_register(PC, Mem, N),
    Code is div(N, 100),
    Argument is mod(N, 100).

% one_instruction(State, NewState).
one_instruction(State,
		NewState) :-
    fetch_instruction(State, Code, Arg),
    run_instruction(Code, Arg, State, NewState).

execution_loop(State,
	       Out) :-
    %% check if State is not halted
    State = state(_, _, _, _, _, _), !,
    one_instruction(State, NextState),
    execution_loop(NextState, Out).

execution_loop(halted_state(_, _, _, _, Out, _),
	       Out) :- !.

%%% label linker

% simulating dictionary using list of tuples
lookup(Key, [(Key, Value) | _], Value).

lookup(Key, [(OtherKey, _) | Dict], Value) :-
    Key \= OtherKey,
    lookup(Key, Dict, Value).

create_label_dictionary(Instructions,
			UnLabeledInstructions,
			LabelDict) :-
    create_label_dictionary(Instructions,
			    0,
			    UnLabeledInstructions,
			    LabelDict).

% matching label definition
create_label_dictionary([ref(Label, Instruction) | Xs],
			MemoryAddress,
			[Instruction | Ys],
			[(UpperCaseLabel, MemoryAddress) | RestDict]) :-
    !,
    string_upper(Label, UpperCaseLabel),
    NextAddress is MemoryAddress + 1,
    create_label_dictionary(Xs, NextAddress, Ys, RestDict).

% match other instruction
create_label_dictionary([Instruction | Xs],
			MemoryAddress,
			[Instruction | Ys],
			Dict) :-
    NextAddress is MemoryAddress + 1,
    create_label_dictionary(Xs, NextAddress, Ys, Dict).
create_label_dictionary([], _, [], []).

% label reference
replace_reference([instruction(dat, ref(_)) | _], _, _) :-
    %% this particular unification of the replace_reference reject (fail) the
    %% dat instruction with a label reference as argument.
    %% eg.: dat 30 // is valid
    %%      dat labelname // rejected
    !,
    fail.     

replace_reference([instruction(Code, ref(Label)) | Xs],
	   Dict,
	   [instruction(Code, Address) | Ys]) :-
    !,
    string_upper(Label, UpperCaseLabel),
    lookup(UpperCaseLabel, Dict, Address),
    replace_reference(Xs, Dict, Ys).
replace_reference([Instruction | Xs],
	   Dict,
	   [Instruction | Ys]) :-
    replace_reference(Xs, Dict, Ys).
replace_reference([], _, []).

link_label(Instructions, LinkedInstructions) :-
    create_label_dictionary(Instructions,
			    UnLabeledInstructions,
			    LabelDict),
    replace_reference(UnLabeledInstructions,
		      LabelDict,
		      LinkedInstructions).

pad_mem(Mem, PadMem) :-
    pad_mem(Mem, 99, PadMem).

pad_mem([ A | Rest], N, [ A | NewRest]) :-
    N >= 0, N < 100,
    N1 is N - 1,
    pad_mem( Rest, N1, NewRest).

pad_mem([], N, [0 | NewRest]) :-
    N >= 0, N < 100,
    N1 is N - 1,
    pad_mem([], N1, NewRest).

pad_mem([], N, []) :-
    N < 0.
    

instruction_code_type(add, 1).
instruction_code_type(sub, 2).
instruction_code_type(sta, 3).
instruction_code_type(lda, 5).
instruction_code_type(bra, 6).
instruction_code_type(brz, 7).
instruction_code_type(brp, 8).

instruction_code(instruction(Type, XX), N) :-
    instruction_code_type(Type, CodeType),
    N is CodeType * 100 + XX.
instruction_code(instruction(inp), 901).
instruction_code(instruction(out), 902).
instruction_code(instruction(hlt), 0).
instruction_code(instruction(dat), 0).
instruction_code(instruction(dat, XXX), XXX).

lmc_load(Filename, Mem) :-
    open(Filename, read, Stream),
    read_all_lines(Stream, Instructions),
    close(Stream),
    link_label(Instructions, LinkedInstructions),
    maplist(instruction_code, LinkedInstructions, InstructionCodes),
    pad_mem(InstructionCodes, Mem).

lmc_run(Filename, In, Out) :-
    lmc_load(Filename, Mem),
    execution_loop(state(0, 0, Mem, In, [], noflag), Out).

%%% file parser

read_all_lines(Stream, Instructions) :-
    read_line(Stream, Line),
    Line \= "",
    !,
    split_string(Line, Words),
    parse_next_instruction(Words, Value),
    read_all_lines(Stream, Vs),
    append(Value, Vs, Instructions).
read_all_lines(_, []).
read_line(Stream, Word):-
    get_code(Stream, Char),
    check_char_and_read_rest(Char, Chars, Stream),
    string_codes(Word, Chars).
% New line
check_char_and_read_rest(-1,[],_):- !.
check_char_and_read_rest(10, Chars, Stream):-
    !,
    get_code(Stream, NextChar),
    check_char_and_read_rest(NextChar, Chars, Stream).
check_char_and_read_rest(32, Chars, Stream):-
    !,
    get_code(Stream, NextChar),
    check_char_and_read_rest(NextChar, Chars, Stream).
check_char_and_read_rest(Char, [Char | Chars], Stream):-
    get_code(Stream, NextChar),
    check_char_and_read_rest_1(NextChar, Chars, Stream).
check_char_and_read_rest_1(-1,[],_):- !.
check_char_and_read_rest_1(10,[],_):- !.
check_char_and_read_rest_1(Char, [Char | Chars], Stream):-
    get_code(Stream, NextChar),
    check_char_and_read_rest_1(NextChar, Chars, Stream).

parse_next_instruction([], []) :- !.
parse_next_instruction([Token, Value | _], 
		       [instruction(Token, IntValue)]) :-
    has_arg_instruction(Token),
    atom_number(Value, IntValue),
    !.
parse_next_instruction([Token, Value | _], 
		       [instruction(Token, ref(Value))]) :-
    has_arg_instruction(Token),
    !.
parse_next_instruction([Token | _],
		       [instruction(Token)]) :-
    no_arg_instruction(Token),
    !.
parse_next_instruction([Token | Rest],
		       [ref(Token, Value)]) :-
    parse_next_instruction(Rest, [Value | _]).
has_arg_instruction(Token) :-
    member(Token, [add, sub, sta, lda, bra, brz, brp, dat]).
no_arg_instruction(Token) :-
    member(Token, [inp, out, hlt, dat]).

whitespace(X) :-
    string_codes(" \t\r\n", Codes),
    member(X,Codes).

trim(String, NewString) :-
    string_codes(String, Chars),
    trim_char(Chars, NewChars),
    string_codes(NewString, NewChars).

trim_char([C|Cs], Ns) :-
    whitespace(C),
    !,
    trim_char(Cs, Ns).
trim_char(Cs, Cs).

first_word("", "", "").
first_word(String, FirstString, Rest) :-
    string_codes(String, Chars),
    first_word_char(Chars, FirstWordChars, RestChars),
    string_codes(FirstString, FirstWordChars),
    string_codes(Rest, RestChars).

first_word_char([],[],[]) :- !.
first_word_char([C | Cs], [], [C | Cs]) :-
    whitespace(C), !.
first_word_char([C | Cs], [C | Rs], RestChars) :-
    not(whitespace(C)),
    !,
    first_word_char(Cs, Rs, RestChars).
first_word_char(Rest, _, Rest).

split_string(String, []) :-
    trim(String, NewString),
    NewString = "",
    !.
split_string(String, []) :-
    trim(String, NewString),
    sub_string(NewString, 0, 2, _, "//"),
    !.
split_string(String, [FirstAtom | Others]) :-
    trim(String, NewString),
    first_word(NewString, FirstString, Rest),
    string_to_atom(FirstString, FirstAtom),
    split_string(Rest, Others).
