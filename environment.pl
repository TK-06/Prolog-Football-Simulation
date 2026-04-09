:- module(environment, [
    init_env/0, step_physics/0, apply_action/2,
    player/5, player_stat/3, ball/6, goal/3, field_size/2, score/2, match_time/1
]).

:- use_module(utils).

:- dynamic player/5, player_stat/3, ball/6, score/2, match_time/1.

field_size(800, 600).
goal(red, 0, 300).
goal(blue, 800, 300).

init_env :-
    retractall(score(_, _)),
    assertz(score(0, 0)),
    retractall(match_time(_)),
    assertz(match_time(270.0)),
    init_stats,
    random_perm2(red, blue, Team, _),
    reset_positions(Team).

init_stats :-
    retractall(player_stat(_, _, _)),
    forall(between(1, 6, ID), (
        Temp is ID mod 3,
        (Temp == 0 ->
            random_range(3.2,3.3, Speed);
        (Temp == 2->
            random_range(2.6, 3.0, Speed));
            random_range(2.4, 2.8, Speed)
        ),

        random_range(60.0, 80.0, KickPower),
        assertz(player_stat(ID, Speed, KickPower))
    )).

% Reset everyone after a goal or at kickoff.
reset_positions(KickoffTeam) :-
    retractall(player(_, _, _, _, _)),
    retractall(ball(_, _, _, _, _, _)),

    (KickoffTeam == red -> RX = 380 ; RX = 200),
    (KickoffTeam == blue -> BX = 420 ; BX = 600),

    % Red team
    assertz(player(1, red, 50, 300, 0)),
    assertz(player(2, red, 150, 300, 0)),
    assertz(player(3, red, RX, 300, 0)),

    % Blue team
    assertz(player(4, blue, 750, 300, pi)),
    assertz(player(5, blue, 650, 300, pi)),
    assertz(player(6, blue, BX, 300, pi)),

    % Ball starts at midfield
    assertz(ball(400, 300, 0, 0, 0, 0)).
apply_action(PlayerID, goto(TX, TY)) :-
    player(PlayerID, Team, X, Y, Angle),
    ball(Xb,Yb,_,_,_,_),
    angleTo(X, Y, TX, TY, TargetAngle),
    angleTo(X,Y , Xb,Yb , NewFaceAngle),
    signed_angle_diff(Angle, NewFaceAngle, TurnDiff),
    
    apply_action(PlayerID, turn(TurnDiff)),
    player(PlayerID,_,_,_,FinalFaceAngle),

    player_stat(PlayerID, Speed, _),
    distance(X, Y, TX, TY, Dist),
    ( Dist < Speed ->
        TmpX = TX,
        TmpY = TY
    ;
        TmpX is X + Speed * cos(TargetAngle),
        TmpY is Y + Speed * sin(TargetAngle)
    ),

    % Try the forward move first. If blocked, try sidestepping.
    ( \+ (
        player(OtherID, _, OX, OY, _),
        OtherID \= PlayerID,
        distance(TmpX, TmpY, OX, OY, CDist),
        CDist < 22
      ) ->
        NX = TmpX,
        NY = TmpY
    ;
        SlideAngle1 is TargetAngle + pi/2,
        SX1 is X + Speed* cos(SlideAngle1),
        SY1 is Y + Speed * sin(SlideAngle1),

        ( \+ (
            player(OID1, _, OX1, OY1, _),
            OID1 \= PlayerID,
            distance(SX1, SY1, OX1, OY1, CDist1),
            CDist1 < 22
          ) ->
            NX = SX1,
            NY = SY1
        ;
            SlideAngle2 is TargetAngle - pi/2,
            SX2 is X + Speed * cos(SlideAngle2),
            SY2 is Y + Speed * sin(SlideAngle2),

            ( \+ (
                player(OID2, _, OX2, OY2, _),
                OID2 \= PlayerID,
                distance(SX2, SY2, OX2, OY2, CDist2),
                CDist2 < 22
              ) ->
                NX = SX2,
                NY = SY2
            ;
                NX = X,
                NY = Y
            )
        )
    ),

    % Keep players inside the field.
    field_size(W, H),
    PlayerOffset = 50,
    Up is -PlayerOffset, Down is H + PlayerOffset, Left is -PlayerOffset, Right is W + PlayerOffset, 
    clamp(NX, Left , Right ,FinalX),
    clamp(NY, Up, Down, FinalY),

    retract(player(PlayerID, Team, X, Y, _)),
    assertz(player(PlayerID, Team, FinalX, FinalY, FinalFaceAngle)).

apply_action(PlayerID, flank(TX, TY, Dist)) :-
    ball(Xb,Yb,_,_,_,_),
    player(PlayerID, _ , Xp,Yp, _),
    angleTo(Xb,Yb,TX,TY, TargetAngle),
    
    distance(Xp,Yp,Xb,Yb, B2PDist),

    (B2PDist < Dist -> NDist = 24 ; NDist = Dist),

    FlankAngle = TargetAngle + pi,
    
    NX = Xb + NDist * cos(FlankAngle),
    NY = Yb + NDist * sin(FlankAngle),

    apply_action(PlayerID , goto(NX,NY)).

apply_action(PlayerID, turn(DeltaAngle)) :-
    player(PlayerID, Team, X, Y, Angle),
    MaxTurn = 0.15,
    ( DeltaAngle > MaxTurn  -> D = MaxTurn
    ; DeltaAngle < -MaxTurn -> D = -MaxTurn
    ; D = DeltaAngle
    ),
    NA is Angle + D,
    normalize_angle(NA, NAngle),
    retract(player(PlayerID, Team, X, Y, _)),
    assertz(player(PlayerID, Team, X, Y, NAngle)).

apply_action(PlayerID, kick(TX, TY, Distance2Target)) :-
    player(PlayerID, _, X, Y, FaceAngle),
    ball(BX, BY, _, _, _, _),
    distance(X, Y, BX, BY, Dist),
    RequestedPower is Distance2Target/9,
    ( Dist < 60 ->
        player_stat(PlayerID, _, PlayerPower),
        angleTo(BX, BY, TX, TY, TrueAngle),
        random(F),
        InaccuracyFactor is 0.6 * RequestedPower/PlayerPower, %harder kick less acc
        Inaccuracy is (F-0.5) * InaccuracyFactor,
        ActualAngle is TrueAngle + Inaccuracy,
        
        clamp(RequestedPower, 0, PlayerPower, ActualPower),

        angleDifference(ActualAngle, FaceAngle, AngleDiff),
        
        ((AngleDiff < pi/2) ->

            (AccelX is ActualPower * cos(ActualAngle),
            AccelY is ActualPower * sin(ActualAngle),
            retract(ball(BX, BY, VX, VY, _, _)),
            assertz(ball(BX, BY, VX, VY, AccelX, AccelY)))
            ;
            apply_action(PlayerID, flank(TX,TY,50))
        )
    ;
        true
    ).

% Find overlapping players and separate them a bit.
resolve_overlaps :-
    findall((ID1, ID2), (
        player(ID1, _, X1, Y1, _),
        player(ID2, _, X2, Y2, _),
        ID1 < ID2,
        distance(X1, Y1, X2, Y2, Dist),
        Dist < 22
    ), Overlaps),
    apply_push_apart(Overlaps).

apply_push_apart([]).
apply_push_apart([(ID1, ID2) | T]) :-
    ( player(ID1, Team1, X1, Y1, A1),
      player(ID2, Team2, X2, Y2, A2) ->
        distance(X1, Y1, X2, Y2, Dist),
        ( Dist < 22 ->
            (Dist < 0.1 -> SafeDist = 0.1 ; SafeDist = Dist),
            Overlap is 22 - SafeDist,
            Push is Overlap / 2.0 + 0.1,
            angleTo(X2, Y2, X1, Y1, AnglePush),

            NX1 is X1 + Push * cos(AnglePush),
            NY1 is Y1 + Push * sin(AnglePush),
            NX2 is X2 - Push * cos(AnglePush),
            NY2 is Y2 - Push * sin(AnglePush),

            retract(player(ID1, Team1, X1, Y1, A1)),
            assertz(player(ID1, Team1, NX1, NY1, A1)),
            retract(player(ID2, Team2, X2, Y2, A2)),
            assertz(player(ID2, Team2, NX2, NY2, A2))
        ;
            true
        )
    ;
        true
    ),
    apply_push_apart(T).

step_physics :-
    match_time(T),
    (T > 0 -> NT is T - 0.04 ; NT = 0),
    retract(match_time(T)),
    assertz(match_time(NT)),

    resolve_overlaps,

    player(3,_,XAtkR, YAtkR,_),
    player(6,_,XAtkB, YAtkB,_),

    ball(X, Y, VX, VY, AX, AY),
    NewVX is VX + AX,
    NewVY is VY + AY,

    Friction = 0.9,
    DampedVX is NewVX * Friction,
    DampedVY is NewVY * Friction,
    NX is X + DampedVX,
    NY is Y + DampedVY,

    ( player(_, _, PX, PY, _),
      distance(NX, NY, PX, PY, PDist),
      PDist < 25  ->
        angleTo(PX, PY, NX, NY, BounceAngle),
        BounceSpeed is sqrt(DampedVX**2 + DampedVY**2) * 0.8 + 2.0,
        FinalVX is BounceSpeed * cos(BounceAngle),
        FinalVY is BounceSpeed * sin(BounceAngle),
        FinalNX is PX + 26 * cos(BounceAngle),
        FinalNY is PY + 26 * sin(BounceAngle)
    ;
        FinalVX = DampedVX,
        FinalVY = DampedVY,
        FinalNX = NX,
        FinalNY = NY
    ),

    field_size(W, H),
    (FinalNX < 0 -> NNX = 0, FNVX is -FinalVX ; FinalNX > W -> NNX = W, FNVX is -FinalVX ; NNX = FinalNX, FNVX = FinalVX),
    (FinalNY < 0 -> NNY = 0, FNVY is -FinalVY ; FinalNY > H -> NNY = H, FNVY is -FinalVY ; NNY = FinalNY, FNVY = FinalVY),

    % Bounce off the goal posts / opening edges.
    ( NNX =< 15,  (Y - 200) * (NNY - 200) < 0 -> BouncedY = 200, BouncedVY is -FNVY
    ; NNX =< 15,  (Y - 400) * (NNY - 400) < 0 -> BouncedY = 400, BouncedVY is -FNVY
    ; NNX >= 785, (Y - 200) * (NNY - 200) < 0 -> BouncedY = 200, BouncedVY is -FNVY
    ; NNX >= 785, (Y - 400) * (NNY - 400) < 0 -> BouncedY = 400, BouncedVY is -FNVY
    ; BouncedY = NNY, BouncedVY = FNVY
    ),

    (abs(FNVX) < 0.2 -> StopVX = 0 ; StopVX = FNVX),
    (abs(BouncedVY) < 0.2 -> StopVY = 0 ; StopVY = BouncedVY),

    ((
        XAtkR < XAtkB,
        distance(XAtkR,YAtkR ,X, Y, DistanceFromR),
        DistanceFromR < 30,
        distance(XAtkB,YAtkB ,X, Y, DistanceFromB),
        DistanceFromB < 30
     ) ->
        (
            random(F),
            NextVY is (F-0.5)*10 + StopVY 
        ); NextVY = StopVY
    ),
    NextVX = StopVX,

    retract(ball(X, Y, VX, VY, AX, AY)),
    assertz(ball(NNX, BouncedY, NextVX, NextVY, 0, 0)),
    check_goal.

check_goal :-
    ball(X, Y, _, _, _, _),
    ( X < 15, Y > 200, Y < 400 ->
        score(R, B),
        NB is B + 1,
        retract(score(R, B)),
        assertz(score(R, NB)),
        reset_positions(red)
    ; X > 785, Y > 200, Y < 400 ->
        score(R, B),
        NR is R + 1,
        retract(score(R, B)),
        assertz(score(NR, B)),
        reset_positions(blue)
    ;
        true
    ).