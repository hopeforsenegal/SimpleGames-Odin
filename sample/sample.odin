package example

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(800, 450, "ODIN Sample")

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.DrawText("Congrats! You created your first window!", 190, 200, 20, rl.WHITE)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}