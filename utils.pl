:- module(utils, [distance/5, angleTo/5, addNoise/3, angleDifference/3, signedAngleDiff/3, normalize_angle/2, random_range/3, middleAngle/3,clamp/4]).

distance(X1, Y1, X2, Y2, D) :- 
    D is sqrt((X1 - X2)**2 + (Y1 - Y2)**2).

angleTo(X1, Y1, X2, Y2, A) :- 
    A is atan2(Y2 - Y1, X2 - X1).

addNoise(Val, NoiseLevel, NoisyVal) :-
    random(R), 
    Offset is (2*R - 1) * NoiseLevel, 
    NoisyVal is Val + Offset.

angleDifference(A1, A2, Diff) :-
    signedAngleDiff(A1, A2, SDiff), Diff is abs(SDiff).

signedAngleDiff(Current, Target, Diff) :-
    Diff1 is Target - Current,
    Diff is Diff1 - 2 * pi * floor((Diff1 + pi) / (2 * pi)).

normalize_angle(A, Norm) :-
    Norm is atan2(sin(A), cos(A)).

middleAngle(A, B, Mid) :-
    X is cos(A) + cos(B),
    Y is sin(A) + sin(B),
    (   abs(X) < 1e-9, abs(Y) < 1e-9 ->
        Mid is A + (pi / 2)
    ; 
        Mid is atan2(Y, X)
    ).

random_range(Min, Max, Val) :-
    random(R),
    Val is Min + R * (Max - Min).

clamp(Val , Min, Max , Res) :-
    (Val < Min) -> Res = Min;
    (Val > Max) -> Res = Max;
    Res = Val.