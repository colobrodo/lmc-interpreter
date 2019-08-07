%%%% -*- Emacs Mode: Prolog -*-

print_state(state(Acc, PC, Mem, In, Out, Flag)) :-
    !,
    writeln(Acc),
    writeln(PC),
    enumerate(Mem, IndexedMem),
    maplist(print_memory_cell, IndexedMem),
    nl,
    writeln(In),
    writeln(Out),
    writeln(Flag),
    nl,
    nl.

print_state(_).

enumerate(A, B) :- enumerate(A, 1, B).
enumerate([], _, []).
enumerate([A | As], I, [pair(I, A) | Pairs]) :- NextI is I + 1, enumerate(As, NextI, Pairs).

print_memory_cell(pair(Index, Cell)) :-
    I is Index - 1,
    X is mod(Index, 10),
    X \= 0, !,
    write(" "), format('~|~`0t~d~3+', [I]), write(" : "), format('~|~`0t~d~3+', [Cell]), write(" |").

print_memory_cell(pair(Index, Cell)) :-
    I is Index - 1,
    write(" "),
    format('~|~`0t~d~3+', [I]),
    write(" : "),
    format('~|~`0t~d~3+', [Cell]),
    writeln(" |").

% sequential composition: if first consumer succeed evaluate the second
% esample: consumer_chain(print_state >> run_tests >> append_to_file("passed.log"), State). 
consumer_chain(C1 >> C2, Resource) :-
    consumer_chain(C1, Resource),
    consumer_chain(C2, Resource).
consumer_chain(C1, Resource) :-
    call(C1, Resource).
