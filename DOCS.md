# Prolog RoboCup 5v5 — Code Documentation

---

## Table of Contents

- [main.pl](#mainpl)
- [environment.pl](#environmentpl)
- [ai.pl](#aipl)
- [sensor.pl](#sensorpl)
- [math_utils.pl](#math_utilspl)

---

## main.pl

Entry point and GUI renderer. Handles window creation, player visuals, and the game loop.

---

### `start/0`
```prolog
start :- set_random(seed(random)), environment:init_env, create_gui.
```
Entry point. Seeds the random number generator, initialises the game environment, and launches the GUI.

---

### `create_gui/0`
```prolog
create_gui :- ...
```
Creates the XPCE window (800x600), the green pitch, goal boxes, scoreboard text, clock text, ball visual, player visuals, speed menu, stop button, and starts the game loop timer at 25fps (0.04s interval).

---

### `stop_sim/1`
```prolog
stop_sim(+Frame)
```
Stops and frees the game loop timer, then destroys the GUI window. Called when the Stop button is clicked.

---

### `change_speed/1`
```prolog
change_speed(+SpeedMultiplier)
```
Adjusts simulation speed from the speed menu.
- Below 1x: slows the timer interval down, runs 1 physics step per frame.
- 1x and above: keeps the timer at 0.04s, increases physics steps per frame.

| Speed | Behaviour |
|---|---|
| 0.5x | Timer interval doubled (0.08s), 1 step/frame |
| 1x | Timer at 0.04s, 1 step/frame |
| 2x | Timer at 0.04s, 2 steps/frame |
| 4x | Timer at 0.04s, 4 steps/frame |
| 8x | Timer at 0.04s, 8 steps/frame |

---

### `player_label_text/2`
```prolog
player_label_text(+ID, -Label)
```
Maps a player ID (1–10) to their position label string.

| ID | Label |
|---|---|
| 1, 6 | GK |
| 2, 7 | D1 |
| 3, 8 | D2 |
| 4, 9 | A1 |
| 5, 10 | A2 |

---

### `setup_players/1`
```prolog
setup_players(+Window)
```
Creates and registers the visual elements for all 10 players: a coloured circle, a direction line, and a position label. Red team = IDs 1–5, Blue team = IDs 6–10.

---

### `update_pos_and_dir/4`
```prolog
update_pos_and_dir(+ID, +X, +Y, +Angle)
```
Updates the on-screen position of a player's circle, direction indicator line, and label to follow the player's current coordinates and facing angle.

---

### `game_loop/1`
```prolog
game_loop(+Window)
```
Called every frame by the timer. Runs the following steps:
1. Executes AI decisions and physics `N` times (based on current speed setting).
2. Checks if match time has expired and displays the result.
3. Renders the ball and all players once.
4. Updates the scoreboard and clock display.
5. Flushes the window.

---

## environment.pl

Manages all game state: player data, ball physics, scoring, and collision resolution.

---

### `init_env/0`
```prolog
init_env
```
Resets the entire game state: clears and resets the score to 0–0, sets match time to 270 seconds (displayed as 90), randomises player stats, and places everyone at starting positions.

---

### `init_stats/0`
```prolog
init_stats
```
Randomly assigns two stats to each player (IDs 1–10):
- **Speed**: random float between 1.5 and 2.8 units per frame.
- **Kick Power**: random float between 20.0 and 45.0.

---

### `reset_positions/1`
```prolog
reset_positions(+KickoffTeam)
```
Places all 10 players and the ball at their starting positions. The team that conceded the goal kicks off from closer to the centre. Accepts `red`, `blue`, or `none` (match start).

---

### `apply_action/2` — `goto`
```prolog
apply_action(+PlayerID, goto(+TX, +TY))
```
Moves a player one step toward the target coordinates. Turns toward the target up to a maximum of 0.15 radians per frame, then moves at the player's speed. Includes three-tier collision avoidance:
1. Try moving forward.
2. If blocked, try sliding right (90° tangent).
3. If blocked, try sliding left.
4. If all blocked, stop completely to prevent phasing.

Also clamps the player within field boundaries.

---

### `apply_action/2` — `turn`
```prolog
apply_action(+PlayerID, turn(+DeltaAngle))
```
Rotates a player by `DeltaAngle` radians (capped at ±0.15 per frame). Used for scanning when the ball is out of view.

---

### `apply_action/2` — `kick`
```prolog
apply_action(+PlayerID, kick(+TX, +TY, +RequestedPower))
```
Kicks the ball toward `(TX, TY)` if the player is within 25 units of the ball. Uses the player's actual `KickPower` stat and adds random inaccuracy (±0.3 radians) to simulate imperfect kicks.

---

### `resolve_overlaps/0`
```prolog
resolve_overlaps
```
Finds all pairs of players whose hitboxes overlap (distance < 22 units) and queues them for separation.

---

### `apply_push_apart/1`
```prolog
apply_push_apart(+OverlapList)
```
For each overlapping pair, calculates how much they overlap and pushes both players equally apart along the line connecting them. Adds a small padding to guarantee clean separation.

---

### `step_physics/0`
```prolog
step_physics
```
Advances the simulation by one tick:
1. Decrements the match timer by 0.04 seconds.
2. Resolves player overlaps.
3. Applies ball velocity, adds acceleration, applies friction (0.94).
4. Bounces the ball off field walls.
5. Bounces the ball off goalpost corners.
6. Stops the ball if speed drops below 0.2.
7. Calls `check_goal`.

---

### `check_goal/0`
```prolog
check_goal
```
Checks if the ball has crossed either goal line (x < 15 or x > 785) within the goal mouth (y between 200 and 400). If so, increments the appropriate team's score and resets positions for kickoff.

---

## ai.pl

Controls the decision-making for all 10 players. Each player calls `decide_action` every tick and returns one action.

---

### `role/2`
```prolog
role(+PlayerID, -Role)
```
Maps each player ID to their tactical role.

| IDs | Role |
|---|---|
| 1, 6 | goalkeeper |
| 2, 3, 7, 8 | defender |
| 4, 5, 9, 10 | attacker |

---

### `decide_action/2` — Goalkeeper
```prolog
decide_action(+PlayerID, -Action)  [goalkeeper]
```
Three-state behaviour based on ball position:
1. **Ball in possession** (distance < 30): finds the nearest teammate defender and passes to them.
2. **Ball in danger zone** (within 120 units of goal centre): charges directly at the ball.
3. **Default**: patrols a semi-circle of radius 50 in front of the goal, tracking the ball's angle.

Uses direct ball knowledge (bypasses FOV sensor) so the goalkeeper never loses sight of the ball.

---

### `decide_action/2` — Random Wobble
```prolog
decide_action(_, Action)  [5% random turn]
```
Gives all field players a 5% chance per tick to turn slightly (±1.0 radians), making movement look more natural and less robotic.

---

### `decide_action/2` — No Ball in FOV
```prolog
decide_action(+PlayerID, turn(0.15))  [scan]
```
If a field player cannot sense the ball (it is outside their FOV), they turn at maximum speed to scan for it.

---

### `decide_action/2` — Defender
```prolog
decide_action(+PlayerID, -Action)  [defender]
```
Three-state behaviour:
1. **Ball in possession** (distance < 25): passes forward to the closest attacker on the same team.
2. **Ball is in own half** (ball to own goal < 350 units): flanks the ball from behind, approaching from the attacker's side to set up a clean pass.
3. **Ball is far away**: moves to a screening position halfway between own goal and ball.

---

### `decide_action/2` — Attacker
```prolog
decide_action(+PlayerID, -Action)  [attacker]
```
Three-state behaviour:
1. **Ball is in own half** (ball to own goal < 350 units): holds a waiting position at a fixed X coordinate at the opponent's side, tracking the ball's Y.
2. **Ball in possession** (distance < 25): shoots directly at the opponent's goal.
3. **Default**: approaches the ball from the goal-side (positions behind the ball relative to target goal) to set up a clean shot.

---

## sensor.pl

Simulates imperfect player perception. All sensing is limited by field of view and distance-based noise.

---

### `in_fov/3`
```prolog
in_fov(+PlayerID, +TX, +TY)
```
Succeeds if the target `(TX, TY)` is within the player's 180° field of view (±90° from their facing angle). Used as a gate for all other sense predicates.

---

### `sense_ball/3`
```prolog
sense_ball(+PlayerID, -SensedX, -SensedY)
```
Returns the ball's position with added noise if the ball is in the player's FOV. Noise level scales with distance (5% of distance). Fails if the ball is not in FOV.

---

### `sense_goal/4`
```prolog
sense_goal(+PlayerID, +TargetTeam, -SensedX, -SensedY)
```
Returns the position of `TargetTeam`'s goal with added noise if it is in the player's FOV. Noise level scales with distance (2% of distance).

---

### `sense_teammate/4`
```prolog
sense_teammate(+PlayerID, +TeammateID, -SensedX, -SensedY)
```
Returns the position of a specific teammate with added noise if they are in the player's FOV. Noise level scales with distance (2% of distance). Fails if the teammate is the same player or not in FOV.

---

## math_utils.pl

Pure geometry and math utilities. No game state — all predicates are stateless.

---

### `distance/5`
```prolog
distance(+X1, +Y1, +X2, +Y2, -D)
```
Returns the Euclidean distance between two points.
```
D = sqrt((X2-X1)² + (Y2-Y1)²)
```

---

### `angle_to/5`
```prolog
angle_to(+X1, +Y1, +X2, +Y2, -Angle)
```
Returns the angle in radians from point 1 to point 2, using `atan2`. Result is in the range `[-π, π]`.

---

### `add_noise/3`
```prolog
add_noise(+Value, +NoiseLevel, -NoisyValue)
```
Adds a random offset in the range `[-NoiseLevel, +NoiseLevel]` to `Value`. Used by sensors to simulate imperfect perception.

---

### `angle_diff/3`
```prolog
angle_diff(+A1, +A2, -Diff)
```
Returns the absolute angular difference between two angles, correctly handling wraparound (e.g. the difference between 170° and -170° is 20°, not 340°).

---

### `signed_angle_diff/3`
```prolog
signed_angle_diff(+Current, +Target, -Diff)
```
Returns the signed angular difference from `Current` to `Target`. Positive means turn left, negative means turn right. Handles full wraparound.

---

### `normalize_angle/2`
```prolog
normalize_angle(+Angle, -Normalized)
```
Wraps any angle into the range `[-π, π]` using `atan2(sin(A), cos(A))`.

---

### `random_range/3`
```prolog
random_range(+Min, +Max, -Value)
```
Generates a uniformly distributed random float between `Min` and `Max`.
