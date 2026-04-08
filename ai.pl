:- module(ai, [decide_action/2]).
:- use_module(sensor). :- use_module(environment). :- use_module(math_utils).

role(1, goalkeeper). role(6, goalkeeper).
role(2, defender). role(3, defender). role(7, defender). role(8, defender).
role(4, attacker). role(5, attacker). role(9, attacker). role(10, attacker).

% [CHANGED] 1. GOALKEEPER: Semi-circle tracking, intercepting, and passing to defenders.
decide_action(PlayerID, Action) :-
    role(PlayerID, goalkeeper), !,
    environment:player(PlayerID, Team, PX, PY, _),
    (Team == red -> TargetTeam = blue, OwnGoalX = 0, OwnGoalY = 300 ; TargetTeam = red, OwnGoalX = 800, OwnGoalY = 300),
    
    % Give GK "absolute" vision of the ball so they don't spin looking for it
    environment:ball(BX, BY, _, _, _, _), 
    math_utils:distance(PX, PY, BX, BY, DistToBall),
    math_utils:distance(OwnGoalX, OwnGoalY, BX, BY, BallToGoalCenter),
    
    (DistToBall < 30 ->
        % 1. WE HAVE THE BALL: Execute a precise pass to the closest defender
        findall(Dist-DX-DY, (
            role(DefID, defender),
            environment:player(DefID, Team, DX, DY, _),
            math_utils:distance(PX, PY, DX, DY, Dist)
        ), DefenderDistances),
        
        % Sort by distance and extract the closest defender's data
        ( keysort(DefenderDistances, [_ClosestDefDist-TargetDX-TargetDY | _]) ->
            Action = kick(TargetDX, TargetDY, 30)
        ;
            % Fallback: Just kick it away if no defender is found alive/registered
            environment:goal(TargetTeam, GX, GY), Action = kick(GX, GY, 30)
        )
    ; BallToGoalCenter < 120 ->
        % 2. BALL IN INTERCEPT ZONE: If the ball enters the 120-radius half-circle, charge it!
        Action = goto(BX, BY)
    ;
        % 3. GUARD THE GOAL ON A SEMI-CIRCLE
        math_utils:angle_to(OwnGoalX, OwnGoalY, BX, BY, AngleToBall),
        
        % Set the radius of the semi-circle (distance from goal line)
        Radius = 50,
        
        TargetX is OwnGoalX + Radius * cos(AngleToBall),
        TargetY is OwnGoalY + Radius * sin(AngleToBall),
        
        Action = goto(TargetX, TargetY)
    ).

% [UNCHANGED] --- FIELD PLAYERS FALLBACKS ---
% 5% chance to randomly adjust angle (makes them look alive). GKs ignore this now!
decide_action(_, Action) :- random(R), R < 0.05, !, random_between(-10, 10, RandAngle), N is RandAngle / 10, Action = turn(N).
% If a field player doesn't see the ball, spin to scan for it.
decide_action(PlayerID, Action) :- \+ sensor:sense_ball(PlayerID, _, _), !, Action = turn(0.15).


% [UNCHANGED] 2. DEFENDER (Flanking to pass to attacker)
decide_action(PlayerID, Action) :-
    role(PlayerID, defender), !,
    environment:player(PlayerID, Team, PX, PY, _), sensor:sense_ball(PlayerID, BX, BY),
    
    (Team == red -> OwnGoalX = 0, OwnGoalY = 300 ; OwnGoalX = 800, OwnGoalY = 300),
    
    math_utils:distance(PX, PY, BX, BY, DistToBall),
    math_utils:distance(BX, BY, OwnGoalX, OwnGoalY, BallToGoalDist),
    
    findall(Dist-AX-AY, (
        role(AttackerID, attacker),
        environment:player(AttackerID, Team, AX, AY, _),
        math_utils:distance(BX, BY, AX, AY, Dist)
    ), AttackerDistances),
    
    keysort(AttackerDistances, [_ClosestAttackerDist-TargetAX-TargetAY | _]),
    
    (DistToBall < 25 ->
        Action = kick(TargetAX, TargetAY, 25)
    ; 
        BallToGoalDist < 350 ->
            math_utils:angle_to(BX, BY, TargetAX, TargetAY, AngleToAttacker),
            ApproachAngle is AngleToAttacker + 3.14159,
            StandoffX is BX + 45 * cos(ApproachAngle),
            StandoffY is BY + 45 * sin(ApproachAngle),
            math_utils:distance(PX, PY, StandoffX, StandoffY, DistToApproach),
            
            (DistToApproach < 20 ->
                Action = goto(BX, BY)
            ;
                Action = goto(StandoffX, StandoffY)
            )
        ;
            ScreenX is OwnGoalX + (BX - OwnGoalX) * 0.5, ScreenY is OwnGoalY + (BY - OwnGoalY) * 0.5,
            Action = goto(ScreenX, ScreenY)
    ).

% [UNCHANGED] 3. ATTACKER 
decide_action(PlayerID, Action) :-
    role(PlayerID, attacker),
    environment:player(PlayerID, Team, PX, PY, _), sensor:sense_ball(PlayerID, BX, BY),
    
    (Team == red -> TargetTeam = blue, OwnGoalX = 0, OwnGoalY = 300, WaitX = 500 ; TargetTeam = red, OwnGoalX = 800, OwnGoalY = 300, WaitX = 300),
    
    environment:goal(TargetTeam, GX, GY),
    math_utils:distance(PX, PY, BX, BY, DistToBall),
    math_utils:distance(BX, BY, OwnGoalX, OwnGoalY, BallToGoalDist),
    
    (BallToGoalDist < 350 ->
        Action = goto(WaitX, BY)
    ;
    DistToBall < 25 ->
        Action = kick(GX, GY, 25)
    ; 
        math_utils:angle_to(BX, BY, GX, GY, AngleToGoal),
        ApproachAngle is AngleToGoal + 3.14159,
        AX is BX + 45 * cos(ApproachAngle),
        AY is BY + 45 * sin(ApproachAngle),
        math_utils:distance(PX, PY, AX, AY, DistToApproach),
        
        (DistToApproach < 20 ->
            Action = goto(BX, BY)
        ;
            Action = goto(AX, AY)
        )
    ).