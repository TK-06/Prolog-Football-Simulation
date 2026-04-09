# Prolog Football Simulation V2

A 5v5 football simulator built in SWI-Prolog with a simple XPCE GUI, role-based player AI, noisy perception, and lightweight ball physics.

The project renders a live match between the Red and Blue teams on an `800 x 600` pitch. Every player is controlled by Prolog rules, and the simulation updates continuously through the main game loop.

## Features

- 10 autonomous players split into two 5-player teams
- Distinct roles for goalkeeper, defenders, and attackers
- Ball sensing with field-of-view limits and distance-based noise
- Ball movement, friction, rebounds, scoring, and automatic kickoffs
- Player collision avoidance plus overlap resolution
- Adjustable simulation speed from the GUI
- On-screen scoreboard, timer, facing direction, and player role labels

## Requirements

- [SWI-Prolog](https://www.swi-prolog.org/Download.html)
- XPCE support enabled in your SWI-Prolog installation

On Windows, XPCE is usually included with the standard SWI-Prolog installer.

## Running The Project

Open a terminal in the project folder and start SWI-Prolog:

```bash
swipl main.pl
```

Then run:

```prolog
?- start.
```

This opens the simulation window and starts the match.

## Controls

- `stop`: closes the window and ends the simulation
- `speed`: changes the simulation rate to `0.5x`, `1x`, `2x`, `4x`, or `8x`

At speeds above `1x`, the program keeps the same render interval and performs multiple simulation steps per frame.

## Match Rules

- The field size is `800 x 600`
- The left goal belongs to Red's side, and the right goal belongs to Blue's side
- A goal is counted when the ball crosses inside the goal opening
- After a goal, players and the ball reset for kickoff
- The match timer starts at `270.0` seconds in the current codebase

## AI Overview

Each team has:

- `GK`: goalkeeper
- `D1`, `D2`: defenders
- `A1`, `A2`: attackers

### Goalkeeper

- Tracks the ball relative to its own goal
- Rushes out when the ball enters the danger zone
- Passes to the nearest defender when in possession
- Repositions along a defensive arc in front of goal

### Defenders

- Screen the space between the ball and their own goal
- Move into flanking positions when the ball is in a dangerous area
- Pass forward to the nearest attacker after winning the ball

### Attackers

- Move behind the ball relative to the target goal
- Wait in attacking positions when the ball is deep in their own half
- Shoot toward goal once close enough to kick

## Perception Model

The `sensor.pl` module gives players limited awareness:

- Players only detect objects inside a forward field of view
- Ball position includes more noise as distance increases
- Goal and teammate sensing also include noise
- Goalkeepers bypass noisy ball sensing and read the real ball position directly

## Physics Model

The `environment.pl` module handles the simulation state:

- Ball acceleration is applied from kicks
- Velocity is damped by friction each update
- The ball rebounds from walls and nearby players
- Goal-edge collisions are handled around the mouth of the goal
- Overlapping players are pushed apart to reduce clipping

## Project Structure

```text
main.pl          Entry point, GUI setup, render loop, controls
environment.pl   World state, physics, scorekeeping, match timer
ai.pl            Role-based decision logic for all players
sensor.pl        Field-of-view checks and noisy sensing
math_utils.pl    Distance, angles, normalization, randomness
```

## Starting Point For Development

If you want to extend the simulator, good next steps are:

- tune movement, kick power, or friction values
- add formations or more advanced team tactics
- improve collision handling and ball possession logic
- expose match settings such as field size or timer length
- add logging or statistics for shots, passes, and possession

## Notes

- The window title in the current implementation is `Prolog RoboCup 5v5`
- The simulation uses random player stats at the start of each match
- If XPCE is missing, the program may load but fail when creating the GUI

## Contributors

- [TK-06](https://github.com/TK-06) - Developer
- [chain2z](https://github.com/chain2z) - Developer
- Claude by Anthropic — AI Assistant
