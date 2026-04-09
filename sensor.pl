:- module(sensor, [senseBall/3]).
:- use_module(environment). :- use_module(utils).

inFov(PlayerID, Xt, Yt) :-
    player(PlayerID, _, Xp, Yp, Ap), 
    angleTo(Xp, Yp, Xt, Yt, A),
    angleDifference(Ap, A, AD),
    AD < pi*1/3. %120 deg fov

senseBall(PlayerID, Xfinal, Yfinal) :-
    ball(Xb, Yb, _, _, _, _), 
    player(PlayerID, _, Xp, Yp, _),  

    inFov(PlayerID, Xb, Yb),
    distance(Xp, Yp, Xb, Yb, Distance),

    %noise
    NoiseIntensity is Distance * 0.05, 
    addNoise(Xb, NoiseIntensity , Xfinal), 
    addNoise(Yb, NoiseIntensity , Yfinal).
