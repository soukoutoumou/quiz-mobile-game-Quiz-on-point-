# Quiz on Point
A mobile quiz game built with Godot featuring multiple game modes with shared foundations but distinct gameplay logic and mechanics.

## Overview

Quiz on Point is a mobile quiz game developed in Godot, built around the idea of delivering multiple gameplay experiences using a shared quiz foundation. While all modes are based on answering questions, each introduces its own pacing, scoring logic, and challenge structure.

The project focuses on implementing distinct game logic systems on top of a common core, allowing for variation in gameplay while maintaining consistency in design. Players can engage with different modes that emphasize speed, accuracy, or endurance, supported by features such as performance tracking, achievements, and dynamic bonus mechanics.

This project serves both as a functional game and as a demonstration of structuring reusable systems with mode-specific behavior.

## Core Features

- **Multiple Game Modes**  
  Three distinct quiz modes built on a shared foundation, each with different gameplay logic and challenge structure.

- **Shared Quiz System**  
  Common question handling, answer validation, and flow reused across all modes.

- **Distinct Gameplay Logic per Mode**  
  Each mode modifies pacing, scoring, and progression to create varied player experiences.

- **Performance Tracking**  
  Best scores and results are saved to track player improvement over time.

- **Achievements System**  
  Milestone-based progression that rewards player performance and engagement.

- **Active Skills & Bonus Mechanics**  
  Players can select 1 out of 3 available skills before gameplay, adding a strategic layer to each run. In addition, systems such as *Quickshot* and *Streak* introduce dynamic scoring bonuses, with behavior that varies depending on the game mode.

## Gameplay Flow

Each session follows a consistent structure across all game modes:

1. Select a game mode  
2. Review the mode-specific rules  
3. Choose 1 out of 3 available skills  
4. Play through the quiz  
5. View results and performance  
6. Restart or try a different mode

## Game Modes

### Rush Mode

Rush Mode is a fast-paced gameplay mode centered around time management and reaction speed.

The player starts with a limited amount of time (30 seconds), which continuously decreases. Correct answers reward additional time, with the amount scaling based on the current answer streak. Fast responses activate the *Quickshot* bonus, doubling the time gained.

Incorrect answers increase the rate at which the timer decreases, adding pressure and making recovery more difficult as mistakes accumulate.

This mode emphasizes speed, consistency, and maintaining streaks under pressure.

### Memory Clash

Memory Clash is a completion-based mode focused on efficiency and consistency.

The player is given a fixed pool of 30 questions. The objective is to clear all questions as quickly as possible. The timer starts at 0 and increases over time, tracking total completion duration.

Correct answers remove questions from the pool, while incorrect answers keep them in play until they are answered correctly. This creates a repetition-based challenge where mistakes directly impact total completion time.

As the player builds a streak, the timer progression slows down, rewarding consistent performance. Fast answers activate the *Quickshot* bonus, reducing the total time.

This mode emphasizes accuracy, memory, and minimizing mistakes to achieve the best possible completion time.

### Bet Arena

Bet Arena is a risk-reward driven mode centered around resource management and decision-making.

The player starts with a fixed amount of bet coins (30), and each question requires a participation fee that increases progressively every few rounds. If the player cannot afford the fee, the run ends.

For each question, the player places a bet. A correct answer returns the original bet along with a bonus percentage, while an incorrect answer results in losing the bet. The reward multiplier is influenced by factors such as question difficulty and a dynamic "House Mood" variable, introducing controlled randomness into outcomes.

Building a streak increases the reward percentage, encouraging consistent performance. Fast answers activate the *Quickshot* bonus, preventing the participation fee from increasing for that round.

This mode emphasizes risk management, strategic decision-making, and balancing reward potential against possible losses.

## Shared Systems

The game is built on a set of reusable core systems that support all gameplay modes while allowing for mode-specific variations.

- **Question Handling System**  
  A unified system for managing question flow, answer validation, and progression across all modes.

- **Scoring & Progress Tracking**  
  Tracks player performance, including best results and session outcomes, enabling comparison and improvement over time.

- **Streak System**  
  A dynamic system that rewards consecutive correct answers, influencing gameplay differently depending on the active mode.

- **Quickshot Mechanic**  
  A timing-based bonus that activates on fast responses, modifying rewards or penalties based on the current mode.

- **Skill Selection System**  
  Players choose 1 out of 3 available skills before each run, introducing strategic variation while integrating with the core gameplay loop.

- **Persistent Data System**  
  Handles saving and loading of player progress, including achievements and best performances.
