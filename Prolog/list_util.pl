%%%% -*- Emacs Mode: Prolog -*-

range(0, [0]) :- !.
range(N, [N | Rest]) :- N1 is N - 1, range(N1, Rest).
