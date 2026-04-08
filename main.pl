:- use_module(library(pce)).
:- use_module(environment).
:- use_module(sensor).
:- use_module(ai).
:- use_module(math_utils).

% [UNCHANGED] Added sim_steps/1 to track how many math calculations to do per render frame
:- dynamic vis_obj/2, main_timer/1, sim_steps/1.

% [UNCHANGED]
start :-
    set_random(seed(random)), environment:init_env, create_gui.

% [UNCHANGED]
create_gui :-
    new(Frame, frame('Prolog RoboCup 5v5')),
    new(Window, picture), send(Window, size, size(800, 600)),
    asserta(vis_obj(window, Window)), 
    
    % Default to 1 math step per render frame
    asserta(sim_steps(1)),
    
    new(Dialog, dialog), 
    send(Dialog, append, button(stop, message(@prolog, stop_sim, Frame))),
    
    new(SpeedMenu, menu(speed, choice, message(@prolog, change_speed, @arg1))),
    send_list(SpeedMenu, append, [0.5, 1.0, 2.0, 4.0, 8.0]),
    send(SpeedMenu, selection, 1.0),
    send(Dialog, append, SpeedMenu),
    
    send(Frame, append, Window), 
    send(Dialog, below, Window), 
    send(Frame, open),
    
    send(Window, display, new(BG, box(800,600))), send(BG, fill_pattern, colour(green)),
    send(Window, display, new(RG, box(15, 200)), point(0, 200)), send(RG, fill_pattern, colour(red)),
    send(Window, display, new(BG_Goal, box(15, 200)), point(785, 200)), send(BG_Goal, fill_pattern, colour(blue)),

    new(ScoreText, text('Red: 0      Blue: 0')), send(ScoreText, font, font(helvetica, bold, 24)),
    send(Window, display, ScoreText, point(300, 20)), asserta(vis_obj(score, ScoreText)),
    
    new(ClockText, text('Time: 90.00')), send(ClockText, font, font(helvetica, bold, 24)),
    send(Window, display, ClockText, point(350, 50)), asserta(vis_obj(clock, ClockText)),

    new(BallVis, circle(14)), send(BallVis, fill_pattern, colour(white)),
    send(Window, display, BallVis), asserta(vis_obj(ball, BallVis)),
    
    setup_players(Window),
    
    new(Timer, timer(0.04, message(@prolog, game_loop, Window))), 
    send(Timer, start), asserta(main_timer(Timer)).

% [UNCHANGED]
stop_sim(Frame) :-
    main_timer(Timer), send(Timer, stop), send(Timer, free), retract(main_timer(Timer)),
    send(Frame, destroy), writeln('Simulation correctly terminated.').

% [UNCHANGED]
change_speed(SpeedArg) :-
    (number(SpeedArg) -> SpeedMultiplier = SpeedArg ; atom_number(SpeedArg, SpeedMultiplier)),
    
    retractall(sim_steps(_)),
    
    % If speed is less than 1, we slow down the UI timer and run 1 step.
    % If speed is >= 1, we keep the UI timer at 0.04s, but increase the number of math steps.
    (SpeedMultiplier < 1.0 ->
        Steps = 1, NewInterval is 0.04 / SpeedMultiplier
    ;
        Steps is round(SpeedMultiplier), NewInterval = 0.04
    ),
    asserta(sim_steps(Steps)),
    
    main_timer(OldTimer),
    send(OldTimer, stop), send(OldTimer, free), retract(main_timer(OldTimer)),
    vis_obj(window, Window),
    new(Timer, timer(NewInterval, message(@prolog, game_loop, Window))),
    send(Timer, start), asserta(main_timer(Timer)).

% [CHANGED] Added specific nametags mapping for IDs and implemented text drawing.
player_label_text(1, 'GK').
player_label_text(2, 'D1').
player_label_text(3, 'D2').
player_label_text(4, 'A1').
player_label_text(5, 'A2').
player_label_text(6, 'GK').
player_label_text(7, 'D1').
player_label_text(8, 'D2').
player_label_text(9, 'A1').
player_label_text(10, 'A2').

setup_players(Window) :-
    forall(between(1, 10, ID), (
        (ID =< 5 -> C = red ; C = blue),
        new(PVis, circle(24)), send(PVis, fill_pattern, colour(C)),
        send(Window, display, PVis), asserta(vis_obj(player(ID), PVis)),
        new(DirLine, line(0,0,0,0)), send(Window, display, DirLine), asserta(vis_obj(player_dir(ID), DirLine)),
        
        player_label_text(ID, LblTxt),
        new(LabelVis, text(LblTxt)),
        send(LabelVis, font, font(helvetica, bold, 12)),
        send(LabelVis, colour, colour(black)),
        send(Window, display, LabelVis), asserta(vis_obj(player_label(ID), LabelVis))
    )).

% [CHANGED] Added nametag location updater to follow the player
update_pos_and_dir(ID, X, Y, Angle) :-
    vis_obj(player(ID), PVis), vis_obj(player_dir(ID), LVis), vis_obj(player_label(ID), LabelVis),
    NX is X - 12, NY is Y - 12, send(PVis, x, NX), send(PVis, y, NY),
    EndX is X + 20 * cos(Angle), EndY is Y + 20 * sin(Angle),
    send(LVis, start, point(X, Y)), send(LVis, end, point(EndX, EndY)),
    LX is X - 8, LY is Y - 25, send(LabelVis, x, LX), send(LabelVis, y, LY).

% [UNCHANGED]
game_loop(Window) :-
    % Run the math loop multiple times based on current speed selection
    sim_steps(Steps),
    forall(between(1, Steps, _), (
        environment:match_time(Time),
        (Time > 0 ->
            forall(between(1, 10, ID), (
                (ai:decide_action(ID, Action) -> environment:apply_action(ID, Action) ; true)
            )),
            environment:step_physics
        ; 
            true
        )
    )),

    % Check final time after all math steps are done
    environment:match_time(FinalTime),
    (FinalTime =< 0 -> 
        environment:score(Red, Blue),
        (Red > Blue -> WinnerStr = 'MATCH OVER - Red Wins!'
        ; Blue > Red -> WinnerStr = 'MATCH OVER - Blue Wins!'
        ; WinnerStr = 'MATCH OVER - Tie!'),
        vis_obj(clock, CT), send(CT, string, WinnerStr) 
    ; true),

    % Retrieve updated ball state and draw ONCE per frame
    environment:ball(BX, BY, _, _, _, _), vis_obj(ball, BallVis), send(BallVis, x, BX - 7), send(BallVis, y, BY - 7),
    
    forall(between(1, 10, ID), (
        environment:player(ID, _, PX, PY, Angle), update_pos_and_dir(ID, PX, PY, Angle)
    )),

    environment:score(Red, Blue), vis_obj(score, ST), sformat(ScoreStr, 'Red: ~w      Blue: ~w', [Red, Blue]), send(ST, string, ScoreStr),
    (FinalTime > 0 -> vis_obj(clock, CT), sformat(ClockStr, 'Time: ~2f', [FinalTime]), send(CT, string, ClockStr) ; true),
    
    send(Window, flush).