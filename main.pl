:- use_module(library(pce)).
:- use_module(environment).
:- use_module(sensor).
:- use_module(ai).
:- use_module(utils).

:- dynamic vis_obj/2, main_timer/1, sim_steps/1.

start :-
    set_random(seed(random)), environment:init_env, create_gui.

create_gui :-
    new(Frame, frame('Prolog RoboCup 3v3')),
    new(Window, picture), send(Window, size, size(800, 600)),
    asserta(vis_obj(window, Window)), 
    
    asserta(sim_steps(1)),
    
    
    new(Dialog, dialog), 
    
    send(Dialog, append, button(reset, message(@prolog, reset_sim))),

    send(Dialog, append, button(stop, message(@prolog, stop_sim, Frame))),

    new(SpeedMenu, menu(speed, choice, message(@prolog, change_speed, @arg1))),
    send_list(SpeedMenu, append, ['0.5', '1', '2', '4', '8']),
    send(SpeedMenu, selection, '1'),
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

stop_sim(Frame) :-
    main_timer(Timer), send(Timer, stop), send(Timer, free), retract(main_timer(Timer)),
    send(Frame, destroy).

reset_sim :-
    environment:init_env.

change_speed(SpeedArg) :-
    (number(SpeedArg) -> SpeedMultiplier = SpeedArg ; atom_number(SpeedArg, SpeedMultiplier)),
    
    retractall(sim_steps(_)),
    
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

player_label_text(1, 'GK').
player_label_text(2, 'DR').
player_label_text(3, 'AR').
player_label_text(4, 'GK').
player_label_text(5, 'DB').
player_label_text(6, 'AB').


setup_players(Window) :-
    forall(between(1, 6, ID), (
        (ID =< 3 -> C = red ; C = blue),
        new(PVis, circle(24)), send(PVis, fill_pattern, colour(C)),
        send(Window, display, PVis), asserta(vis_obj(player(ID), PVis)),
        new(DirLine, line(0,0,0,0)), send(Window, display, DirLine), asserta(vis_obj(player_dir(ID), DirLine)),
        
        player_label_text(ID, LblTxt),
        new(LabelVis, text(LblTxt)),
        send(LabelVis, font, font(helvetica, bold, 12)),
        send(LabelVis, colour, colour(black)),
        send(Window, display, LabelVis), asserta(vis_obj(player_label(ID), LabelVis))
    )).
    
update_pos_and_dir(ID, X, Y, Angle) :-
    vis_obj(player(ID), PVis), 
    vis_obj(player_dir(ID), LVis), 
    vis_obj(player_label(ID), LabelVis),
    
    NX is round(X - 12), NY is round(Y - 12), 
    send(PVis, x, NX), send(PVis, y, NY),
    
    EndX is round(X + 20 * cos(Angle)), EndY is round(Y + 20 * sin(Angle)),
    IX is round(X), IY is round(Y),
    send(LVis, start, point(IX, IY)), send(LVis, end, point(EndX, EndY)),
    
    LX is round(X - 8), LY is round(Y - 25), 
    send(LabelVis, x, LX), send(LabelVis, y, LY).

game_loop(Window) :-
    sim_steps(Steps),
    forall(between(1, Steps, _), (
        environment:match_time(Time),
        (Time > 0 ->
            forall(between(1, 6, ID), (
                (ai:decide_action(ID, Action) -> environment:apply_action(ID, Action) ; true)
            )),
            environment:step_physics
        ; 
            true
        )
    )),

    environment:match_time(FinalTime),
    (FinalTime =< 0 -> 
        environment:score(Red, Blue),
        (Red > Blue -> WinnerStr = 'MATCH OVER - Red Wins!'
        ; Blue > Red -> WinnerStr = 'MATCH OVER - Blue Wins!'
        ; WinnerStr = 'MATCH OVER - Tie!'),
        vis_obj(clock, CT), send(CT, string, WinnerStr) 
    ; true),

    environment:ball(BX, BY, _, _, _, _), vis_obj(ball, BallVis), send(BallVis, x, BX - 7), send(BallVis, y, BY - 7),
    
    forall(between(1, 6, ID), (
        environment:player(ID, _, PX, PY, Angle), update_pos_and_dir(ID, PX, PY, Angle)
    )),

    environment:score(Red, Blue), vis_obj(score, ST), sformat(ScoreStr, 'Red: ~w      Blue: ~w', [Red, Blue]), send(ST, string, ScoreStr),
    (FinalTime > 0 -> vis_obj(clock, CT), sformat(ClockStr, 'Time: ~2f', [FinalTime]), send(CT, string, ClockStr) ; true),
    
    send(Window, flush).