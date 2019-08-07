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

whitespace(X):-
    string_codes(" \t\r\n", Codes),
    member(X,Codes).
trim(String, NewString):-
    string_codes(String, Chars),
    trim_char(Chars, NewChars),
    string_codes(NewString, NewChars).
trim_char([C|Cs], Ns):-
    whitespace(C),
    !,
    trim_char(Cs, Ns).
trim_char(Cs, Cs).
first_word("", "", "").
first_word(String, FirstString, Rest):-
    string_codes(String, Chars),
    first_word_char(Chars, FirstWordChars, RestChars),
    string_codes(FirstString, FirstWordChars),
    string_codes(Rest, RestChars).
first_word_char([],[],[]) :- !.
first_word_char([C|Cs], [], [C|Cs]):-
    whitespace(C), !.
first_word_char([C|Cs], [C|Rs], RestChars):-
    not(whitespace(C)),
    !,
    first_word_char(Cs, Rs, RestChars).
first_word_char(Rest, _, Rest).
split_string(String, []):-
	trim(String, NewString),
	NewString = "",
	!.
split_string(String, []):-
    trim(String, NewString),
	sub_string(NewString, 0, 2, _, "//"),
	!.
split_string(String, [FirstAtom | Others]):-
    trim(String, NewString),
    first_word(NewString, FirstString, Rest),
    string_to_atom(FirstString, FirstAtom),
    split_string(Rest, Others).
