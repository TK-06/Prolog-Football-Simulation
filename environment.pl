% [CHANGED] Added logic to prevent phasing and push overlapping players apart.
:- module(environment, [
    init_env/0, step_physics/0, apply_action/2,
    player/5, player_stat/3, ball/6, goal/3, field_size/2, score/2, match_time/1
]).
:- use_module(math_utils).

% [UNCHANGED] Registered dynamic predicates
:- dynamic player/5, player_stat/3, ball/6, score/2, match_time/1.

field_size(800, 600).
goal(red, 0, 300).
goal(blue, 800, 300).

% [UNCHANGED] Initialization
init_env :-
    retractall(score(_,_)), assertz(score(0, 0)),
    retractall(match_time(_)), assertz(match_time(270.0)),
    init_stats,
    reset_positions(none).

% [UNCHANGED] Randomly roll stats for all 10 players
init_stats :-
    retractall(player_stat(_, _, _)),
    forall(between(1, 10, ID), (
        math_utils:random_range(1.5, 2.8, Speed),
        math_utils:random_range(20.0, 45.0, KickPower),
        assertz(player_stat(ID, Speed, KickPower))
    )).

% [UNCHANGED] Field setup
reset_positions(KickoffTeam) :-
    retractall(player(_,_,_,_,_)), retractall(ball(_,_,_,_,_,_)),
    (KickoffTeam == red -> RX = 380 ; RX = 200), (KickoffTeam == blue -> BX = 420 ; BX = 600),

    assertz(player(1, red, 50, 300, 0)), assertz(player(2, red, 150, 150, 0)), assertz(player(3, red, 150, 450, 0)),
    assertz(player(4, red, RX, 250, 0)), assertz(player(5, red, RX, 350, 0)),
    
    assertz(player(6, blue, 750, 300, 3.14)), assertz(player(7, blue, 650, 150, 3.14)), assertz(player(8, blue, 650, 450, 3.14)),
    assertz(player(9, blue, BX, 250, 3.14)), assertz(player(10, blue, BX, 350, 3.14)),
    
    assertz(ball(400, 300, 0, 0, 0, 0)).

% [CHANGED] Smarter sliding mechanics: Checks if the slide path is also blocked. If it is, tries the other direction or stops.
apply_action(PlayerID, goto(TX, TY)) :-
    player(PlayerID, Team, X, Y, Angle), math_utils:angle_to(X, Y, TX, TY, TargetAngle),
    math_utils:signed_angle_diff(Angle, TargetAngle, TurnDiff), MaxTurn = 0.15,
    (TurnDiff > MaxTurn -> D = MaxTurn ; TurnDiff < -MaxTurn -> D = -MaxTurn ; D = TurnDiff),
    NAngleRaw is Angle + D, math_utils:normalize_angle(NAngleRaw, NAngle),
    
    player_stat(PlayerID, Speed, _), math_utils:distance(X, Y, TX, TY, Dist),
    (Dist < Speed -> TmpX = TX, TmpY = TY ; TmpX is X + Speed * cos(NAngle), TmpY is Y + Speed * sin(NAngle)),
    
    % Forward collision check
    ( \+ (player(OtherID, _, OX, OY, _), OtherID \= PlayerID, math_utils:distance(TmpX, TmpY, OX, OY, CDist), CDist < 22) ->
        NX = TmpX, NY = TmpY
    ;
        % Try sliding Right (tangential)
        SlideAngle1 is NAngle + 1.57,
        SX1 is X + (Speed * 0.7) * cos(SlideAngle1),
        SY1 is Y + (Speed * 0.7) * sin(SlideAngle1),
        ( \+ (player(OID1, _, OX1, OY1, _), OID1 \= PlayerID, math_utils:distance(SX1, SY1, OX1, OY1, CDist1), CDist1 < 22) ->
            NX = SX1, NY = SY1
        ;
            % Right is blocked too, Try sliding Left
            SlideAngle2 is NAngle - 1.57,
            SX2 is X + (Speed * 0.7) * cos(SlideAngle2),
            SY2 is Y + (Speed * 0.7) * sin(SlideAngle2),
            ( \+ (player(OID2, _, OX2, OY2, _), OID2 \= PlayerID, math_utils:distance(SX2, SY2, OX2, OY2, CDist2), CDist2 < 22) ->
                NX = SX2, NY = SY2
            ;
                % Total gridlock, stop completely to avoid phasing into someone else.
                NX = X, NY = Y
            )
        )
    ),
    
    % Ensure players don't slide off the field
    field_size(W, H),
    (NX < 0 -> FinalX = 0 ; NX > W -> FinalX = W ; FinalX = NX),
    (NY < 0 -> FinalY = 0 ; NY > H -> FinalY = H ; FinalY = NY),
    
    retract(player(PlayerID, Team, X, Y, _)), assertz(player(PlayerID, Team, FinalX, FinalY, NAngle)).

% [UNCHANGED]
apply_action(PlayerID, turn(DeltaAngle)) :-
    player(PlayerID, Team, X, Y, Angle), MaxTurn = 0.15,
    (DeltaAngle > MaxTurn -> D = MaxTurn ; DeltaAngle < -MaxTurn -> D = -MaxTurn ; D = DeltaAngle),
    NA is Angle + D, math_utils:normalize_angle(NA, NAngle),
    retract(player(PlayerID, Team, X, Y, _)), assertz(player(PlayerID, Team, X, Y, NAngle)).

% [UNCHANGED]
apply_action(PlayerID, kick(TX, TY, _RequestedPower)) :-
    player(PlayerID, _, X, Y, _), ball(BX, BY, _, _, _, _), math_utils:distance(X, Y, BX, BY, Dist),
    (Dist < 25 ->
        player_stat(PlayerID, _, ActualPower),
        math_utils:angle_to(BX, BY, TX, TY, TrueAngle),
        random(F), Inaccuracy is (F * 0.6) - 0.3,
        ActualAngle is TrueAngle + Inaccuracy,
        AccelX is ActualPower * cos(ActualAngle), AccelY is ActualPower * sin(ActualAngle),
        retract(ball(BX, BY, VX, VY, _, _)), assertz(ball(BX, BY, VX, VY, AccelX, AccelY)) 
    ; true).

% [CHANGED] New function to actively push players apart if their hitboxes overlap
resolve_overlaps :-
    findall((ID1, ID2), (
        player(ID1, _, X1, Y1, _), player(ID2, _, X2, Y2, _), ID1 < ID2,
        math_utils:distance(X1, Y1, X2, Y2, Dist), Dist < 22
    ), Overlaps),
    apply_push_apart(Overlaps).

% [CHANGED] Helper function to calculate the separation vector and nudge players apart
apply_push_apart([]).
apply_push_apart([(ID1, ID2)|T]) :-
    (player(ID1, Team1, X1, Y1, A1), player(ID2, Team2, X2, Y2, A2) ->
        math_utils:distance(X1, Y1, X2, Y2, Dist),
        (Dist < 22 ->
            (Dist < 0.1 -> SafeDist = 0.1 ; SafeDist = Dist),
            Overlap is 22 - SafeDist,
            Push is Overlap / 2.0 + 0.1, % Add small padding to ensure separation
            math_utils:angle_to(X2, Y2, X1, Y1, AnglePush),
            NX1 is X1 + Push * cos(AnglePush), NY1 is Y1 + Push * sin(AnglePush),
            NX2 is X2 - Push * cos(AnglePush), NY2 is Y2 - Push * sin(AnglePush),
            retract(player(ID1, Team1, X1, Y1, A1)), assertz(player(ID1, Team1, NX1, NY1, A1)),
            retract(player(ID2, Team2, X2, Y2, A2)), assertz(player(ID2, Team2, NX2, NY2, A2))
        ; true)
    ; true),
    apply_push_apart(T).

% [CHANGED] Added resolve_overlaps call at the beginning of the physics step
step_physics :-
    match_time(T), (T > 0 -> NT is T - 0.04 ; NT = 0), retract(match_time(T)), assertz(match_time(NT)),
    
    resolve_overlaps,
    
    ball(X, Y, VX, VY, AX, AY),
    NewVX is VX + AX, NewVY is VY + AY,
    Friction = 0.94, DampedVX is NewVX * Friction, DampedVY is NewVY * Friction,
    NX is X + DampedVX, NY is Y + DampedVY,
    
    (player(_, _, PX, PY, _), math_utils:distance(NX, NY, PX, PY, PDist), PDist < 30 ->
        math_utils:angle_to(PX, PY, NX, NY, BounceAngle),
        BounceSpeed is sqrt(DampedVX**2 + DampedVY**2) * 0.8 + 2.0,
        FinalVX is BounceSpeed * cos(BounceAngle), FinalVY is BounceSpeed * sin(BounceAngle),
        FinalNX is PX + 31 * cos(BounceAngle), FinalNY is PY + 31 * sin(BounceAngle)
    ;
        FinalVX = DampedVX, FinalVY = DampedVY, FinalNX = NX, FinalNY = NY
    ),
    
    field_size(W, H),
    (FinalNX < 0 -> NNX = 0, FNVX is -FinalVX ; FinalNX > W -> NNX = W, FNVX is -FinalVX ; NNX = FinalNX, FNVX = FinalVX),
    (FinalNY < 0 -> NNY = 0, FNVY is -FinalVY ; FinalNY > H -> NNY = H, FNVY is -FinalVY ; NNY = FinalNY, FNVY = FinalVY),
    
    ( NNX =< 15, (Y - 200) * (NNY - 200) < 0 -> BouncedY = 200, BouncedVY is -FNVY
    ; NNX =< 15, (Y - 400) * (NNY - 400) < 0 -> BouncedY = 400, BouncedVY is -FNVY
    ; NNX >= 785, (Y - 200) * (NNY - 200) < 0 -> BouncedY = 200, BouncedVY is -FNVY
    ; NNX >= 785, (Y - 400) * (NNY - 400) < 0 -> BouncedY = 400, BouncedVY is -FNVY
    ; BouncedY = NNY, BouncedVY = FNVY
    ),
    
    (abs(FNVX) < 0.2 -> StopVX = 0 ; StopVX = FNVX), (abs(BouncedVY) < 0.2 -> StopVY = 0 ; StopVY = BouncedVY),
    
    retract(ball(X, Y, VX, VY, AX, AY)), assertz(ball(NNX, BouncedY, StopVX, StopVY, 0, 0)), check_goal.

% [UNCHANGED]
check_goal :-
    ball(X, Y, _, _, _, _),
    (X < 15, Y > 200, Y < 400 -> score(R, B), NB is B + 1, retract(score(R,B)), assertz(score(R, NB)), reset_positions(red)
    ; X > 785, Y > 200, Y < 400 -> score(R, B), NR is R + 1, retract(score(R,B)), assertz(score(NR, B)), reset_positions(blue)
    ; true).