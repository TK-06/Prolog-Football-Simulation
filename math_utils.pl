:- module(math_utils, [distance/5, angle_to/5, add_noise/3, angle_diff/3, signed_angle_diff/3, normalize_angle/2, random_range/3]).

distance(X1, Y1, X2, Y2, D) :- 
    D is sqrt((X2 - X1)**2 + (Y2 - Y1)**2).

angle_to(X1, Y1, X2, Y2, A) :- 
    A is atan2(Y2 - Y1, X2 - X1).

add_noise(Val, NoiseLevel, NoisyVal) :-
    random(R), 
    Offset is (R * 2 * NoiseLevel) - NoiseLevel, NoisyVal is Val + Offset.

angle_diff(A1, A2, Diff) :-
    signed_angle_diff(A1, A2, SDiff), Diff is abs(SDiff).

signed_angle_diff(Current, Target, Diff) :-
    Diff1 is Target - Current,
    Diff is Diff1 - 2 * pi * floor((Diff1 + pi) / (2 * pi)).

normalize_angle(A, Norm) :-
    Norm is atan2(sin(A), cos(A)).

% Generate a random float between Min and Max
random_range(Min, Max, Val) :-
    random(R),
    Val is Min + R * (Max - Min).