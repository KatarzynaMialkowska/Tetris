# Tetris Game (Love2D, Lua)

This is a Tetris-style game written in Lua using the [LÖVE 2D framework](https://love2d.org/). The project is structured with a clear configuration, UI components (buttons), and built-in JSON support.

## Features

- Classic Tetris shapes with rotation (I, J, L, O, S, T, Z)
- Custom color configuration for each shape
- Modular button UI system
- JSON support for saving/loading (using `json.lua`)
- Organized screen layout with customizable panels

## File Structure

- `config.lua` – Contains shape definitions, colors, and screen configuration
- `Button.lua` – A reusable button class with hover/click detection
- `json.lua` – Lightweight JSON encoder/decoder
- `main.lua` – *(Not included here but expected)* Main game loop and Love2D callbacks (e.g. `love.update`, `love.draw`, etc.)

## Requirements

- [LÖVE 2D (Love2D)](https://love2d.org/) – You need to have it installed to run the game.
- Lua 5.1+ compatible environment

## Running the Game

To run the game locally:

1. Install [Love2D](https://love2d.org/).
2. Place all `.lua` files in the same folder.
3. Run the folder using LÖVE:
   ```bash
   love .
