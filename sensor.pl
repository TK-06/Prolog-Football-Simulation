:- module(sensor, [sense_ball/3, sense_goal/4, sense_teammate/4]).
:- use_module(environment). :- use_module(math_utils).

in_fov(PlayerID, TX, TY) :-
    environment:player(PlayerID, _, PX, PY, FaceAngle),
    math_utils:angle_to(PX, PY, TX, TY, TargetAngle),
    math_utils:angle_diff(FaceAngle, TargetAngle, Diff), Diff < 1.57. 

sense_ball(PlayerID, SensedX, SensedY) :-
    environment:ball(BX, BY, _, _, _, _), in_fov(PlayerID, BX, BY),
    environment:player(PlayerID, _, PX, PY, _), math_utils:distance(PX, PY, BX, BY, Dist),
    NoiseLevel is Dist * 0.05, math_utils:add_noise(BX, NoiseLevel, SensedX), math_utils:add_noise(BY, NoiseLevel, SensedY).

sense_goal(PlayerID, TargetTeam, SensedX, SensedY) :-
    environment:goal(TargetTeam, GX, GY), in_fov(PlayerID, GX, GY),
    environment:player(PlayerID, _, PX, PY, _), math_utils:distance(PX, PY, GX, GY, Dist),
    NoiseLevel is Dist * 0.02, math_utils:add_noise(GX, NoiseLevel, SensedX), math_utils:add_noise(GY, NoiseLevel, SensedY).

sense_teammate(PlayerID, TeammateID, SensedX, SensedY) :-
    environment:player(PlayerID, Team, PX, PY, _), environment:player(TeammateID, Team, TX, TY, _),
    PlayerID \= TeammateID, in_fov(PlayerID, TX, TY),
    math_utils:distance(PX, PY, TX, TY, Dist), NoiseLevel is Dist * 0.02,
    math_utils:add_noise(TX, NoiseLevel, SensedX), math_utils:add_noise(TY, NoiseLevel, SensedY).