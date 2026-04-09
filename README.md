# Prolog RoboCup 3v3 Football Simulation

A real-time, AI-driven 3v3 football simulation built entirely in Prolog. Two teams — Red and Blue — compete over a 90-second match on an 800x600 pixel pitch, with all player intelligence, physics, and rendering handled in SWI-Prolog using the XPCE GUI library.

## Requirements

- [SWI-Prolog](https://www.swi-prolog.org/Download.html) (version 8.x or later)
- XPCE GUI library (included in the standard SWI-Prolog Windows installer — ensure it is selected during setup)

## Getting Started

1. Clone or download this repository.
2. Open a terminal in the project directory.
3. Launch SWI-Prolog with the main file:

```bash
swipl main.pl
```

4. At the Prolog prompt, type:

```prolog
?- start.
```

A window titled **Prolog RoboCup 3v3** will open and the match begins immediately.

## Controls

| Control | Action |
|---|---|
| **Speed menu** | Set simulation speed: 0.5x, 1x, 2x, 4x, 8x |
| **Reset button** | Reset the match — resets positions, score, and timer |
| **Stop button** | End the simulation and close the window |

## Teams and Roles

Each team has 3 players. Kickoff team is chosen randomly at the start.

| Label | Role | Team |
|---|---|---|
| GK | Goalkeeper | Red (ID 1) |
| DR | Defender | Red (ID 2) |
| AR | Attacker | Red (ID 3) |
| GK | Goalkeeper | Blue (ID 4) |
| DB | Defender | Blue (ID 5) |
| AB | Attacker | Blue (ID 6) |

## AI Behaviour

### Goalkeeper
- **Default**: Patrols a large arc (radius 120) around the goal centre, tracking the ball's angle.
- **Danger zone** (ball within 120 units of goal): Charges directly at the ball.
- **Ball in possession**: Passes to the defender if the opponent attacker is far away (> 70 units), otherwise passes to own attacker.

### Defender
- **Ball in possession** (within 34 units): Passes forward to the nearest attacker.
- **Ball near own goal** (within 400 units): Uses `flank` to approach the ball from behind and set up a pass.
- **Ball far away**: Moves to a screening position halfway between own goal and the ball.

### Attacker
- **Ball near own goal** (within 350 units): Holds a wide waiting position on the opponent's side, mirroring the opponent attacker's Y position.
- **Ball in possession and near opponent goal**: Shoots using `avoidGk` to find the best angle around the goalkeeper. If the defender is close, lofts the ball over to the far post instead.
- **Default**: Uses `flank` to approach the ball from the goal-side, ready to shoot.

### avoidGk (Attacker helper)
Calculates the largest open shooting window by comparing the angles to the top and bottom of the goal against the goalkeeper's body. The attacker shoots through the centre of the bigger gap.

## Physics

- Ball velocity is damped each frame by friction (0.9)
- The ball bounces off field walls and players
- Goalpost corners deflect the ball back onto the pitch
- Ball stops when speed drops below 0.2 units/frame
- Special deflection: if both attackers from opposite teams are simultaneously near the ball, a small random spin is added
- Players have collision detection; overlapping bodies are pushed apart each physics step

## Player Stats

Each player is assigned randomised stats at the start of every match, scaled by role:

| Role (ID mod 3) | Speed Range | Kick Power Range |
|---|---|---|
| Goalkeeper (mod 0) | 3.2 – 3.3 | 60 – 80 |
| Defender (mod 2) | 2.6 – 3.0 | 60 – 80 |
| Attacker (mod 1) | 2.4 – 2.8 | 60 – 80 |

## Perception

Players use a **120-degree field of view**. The ball sensor adds distance-proportional noise (5% of distance), so far-away balls are reported less accurately. The goalkeeper bypasses the FOV sensor entirely and always knows the ball's true position.

## Kick Accuracy

Kick inaccuracy scales with how hard the kick is relative to the player's power stat. A kick at full power is the least accurate. If a player is not facing the target when kicking, they will `flank` into position instead of kicking.

## Match End

When the 90-second timer expires, the clock displays the result:

- `MATCH OVER - Red Wins!`
- `MATCH OVER - Blue Wins!`
- `MATCH OVER - Tie!`

Press **Reset** to start a new match without restarting the program.

## Project Structure

```
main.pl          Entry point, GUI rendering, game loop
environment.pl   Game state, physics engine, scoring, actions
ai.pl            AI decision-making per role
sensor.pl        Simulated ball perception (FOV + noise)
utils.pl         Math utilities (geometry, angles, noise, clamp)
```

## Contributors

- [TK-06](https://github.com/TK-06) - Developer
- [chain2z](https://github.com/chain2z) - Developer
- Claude by Anthropic — AI Assistant
