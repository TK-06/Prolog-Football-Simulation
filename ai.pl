:- module(ai, [decide_action/2]).
:- use_module(sensor). :- use_module(environment). :- use_module(utils).

role(1, goalkeeper). role(4, goalkeeper).
role(2, defender). role(5, defender). 
role(3, attacker). role(6, attacker).

/*
B = ball 
P = player 
G = goal 
Tg = team goal 
Og = Opponent Goal
DF = defender 
ATK = attacker
GK = GoalKeeper*/

%GK
decide_action(PlayerID, Action) :-
    role(PlayerID, goalkeeper), !,

    %get pos
    player(PlayerID, Team, Xp, Yp, _),
    (
        Team == red ->  Opp = blue ,XTg = 0, YTg = 300;
        Opp = red, XTg = 800, YTg = 300
    ),
    
    ball(Xb, Yb, _, _, _, _), 
    distance(Xp, Yp, Xb, Yb, B2PDist),
    distance(XTg, YTg, Xb, Yb, B2TgDist),



   ( B2TgDist < 120 -> Action = goto(Xb, Yb);

    (B2PDist > 35 ->
        angleTo(XTg, YTg, Xb, Yb, Ang2B),
        Radius = 120,
            
        TargetX is XTg + Radius * cos(Ang2B),
        TargetY is YTg + Radius * sin(Ang2B),
            
        Action = goto(TargetX, TargetY));

   
    %else 
    (
        role(OppAtkID , attacker),
        player(OppAtkID , Opp , XOpp, YOpp, _),
        role(TeamDefID, defender),
        player(TeamDefID, Team , XDef,YDef, _),
        role(TeamAtkID, attacker),
        player(TeamAtkID, Team , XAtk,YAtk, _),

        distance(XOpp,YOpp, XDef,YDef, DistDef2Opp),

        (DistDef2Opp > 70 -> (PassToX = XDef, PassToY = YDef); (PassToX = XAtk, PassToY = YAtk)),

        distance(PassToX, PassToY, Xp,Yp, Power),
        Action = kick(PassToX,PassToY, Power)
    )
    ).


% ball not found -> spin
decide_action(PlayerID, Action) :- \+ senseBall(PlayerID, _, _), !, Action = turn(0.15).


% DF
decide_action(PlayerID, Action) :-
    role(PlayerID, defender), !,
    player(PlayerID, Team, Xp, Yp, _), 
    senseBall(PlayerID, Xb, Yb),
    
    (Team == red -> XTg = 0, YTg = 300 ; XTg = 800, YTg = 300),
    
    distance(Xp, Yp, Xb, Yb, B2PDist),
    distance(Xb, Yb, XTg, YTg, B2TgDist),
    
    %find closest Atk
    findall(Dist-AX-AY, (
        role(AttackerID, attacker),
        player(AttackerID, Team, AX, AY, _),
        distance(Xb, Yb, AX, AY, Dist)
    ), AttackerDistances),
    
    keysort(AttackerDistances, [Dist2Target-TargetAX-TargetAY | _]),
    
    %if close to ball 
    (B2PDist < 34 -> (Action = kick(TargetAX, TargetAY, Dist2Target)); 

    %elif close to goal 
    (B2TgDist < 400 ->
         Action = flank(TargetAX, TargetAY , 30)
    );
            XScreen is XTg + (Xb - XTg) * 0.5, 
            YScreen is YTg + (Yb - YTg) * 0.5,
            Action = goto(XScreen, YScreen)
    ).

%ATK

avoidGk(PlayerID , TargetY):-
    player(PlayerID, Team, Xp, Yp, _),
    senseBall(PlayerID, Xb, Yb),
    
    (Team == red -> TargetTeam = blue, XOg = 800
    ; TargetTeam = red,  XOg = 0),

    role(GkID , goalkeeper),
    player(GkID, TargetTeam , XGk, YGk, _),

    UpperBorder is YGk - 25,
    LowerBorder is YGk + 25,

    angleTo(Xb,Yb,XOg,200 ,MaximumUpperAngle),
    angleTo(Xb,Yb,XOg,400 ,MaximumLowerAngle),

    angleTo(Xb,Yb,XGk,UpperBorder,MinimumUpperAngle),
    angleTo(Xb,Yb,XGk,LowerBorder,MinimumLowerAngle),

    angleDifference(MaximumUpperAngle,MinimumUpperAngle, UpperWindow),
    angleDifference(MaximumLowerAngle,MinimumLowerAngle, LowerWindow),

    (UpperWindow > LowerWindow -> middleAngle(MaximumUpperAngle,MinimumUpperAngle, ShootingAngle); middleAngle(MaximumLowerAngle,MinimumLowerAngle, ShootingAngle)),

    YTemp is Yb + (XOg - Xb) * tan(ShootingAngle),
    clamp(YTemp,200,400,TargetY).

decide_action(PlayerID, Action) :-
    role(PlayerID, attacker),
    player(PlayerID, Team, Xp, Yp, _), senseBall(PlayerID, Xb, Yb),
    
    (Team == red -> TargetTeam = blue, XTg = 0, YTg = 300, XOg = 800, WaitX = 500 
    ; TargetTeam = red, XTg = 800, YTg = 300, XOg = 0, WaitX = 300),
    
    goal(TargetTeam, XOg, YOg),
    distance(Xp, Yp, Xb, Yb, B2PDist),
    distance(Xb, Yb, XTg, YTg, B2TgDist),
    distance(Xb, Yb, XOg, YTg, B2OgDist),
    player(OppAttacker, TargetTeam,_,YTAtk, _),
    role(OppAttacker, attacker),
    player(OppDef, TargetTeam,XTDef, YTDef, _),
    role(OppDef, defender),
    field_size(_,H),

    distance(Xb,Yb,XTDef , YTDef , Dist2Def),
    
    %if close to OG 
    (B2TgDist < 350 ->
       (((YTAtk < H/2) -> Yn is YTAtk + 300; Yn is YTAtk - 300),
        Action = goto(WaitX, Yn))
    ;
    %elif close to me close to opp G
    (B2PDist < 35 , B2OgDist < 360) ->
        ((Dist2Def > 60) ->
            (Power is B2OgDist*1.2,
            avoidGk(PlayerID,YTarget),
            Action = kick(XOg, YTarget, Power)
            );

        %else
            (((Yb < H/2) -> Yn = 2000 ; Yn = -1400),
            Action = kick(XOg, Yn, 200)))
    ; 
    %else 
        Action = flank(XOg, YOg, 30)
    );true.