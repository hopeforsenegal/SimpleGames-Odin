package main

import "core:fmt"
import "core:strings"
import raylib "vendor:raylib"

TextAlignment :: enum {
	Left, 
	Center,
	Right,
}

Rectangle :: struct {
	centerPosition: raylib.Vector2,
	size:           raylib.Vector2,
}

Ball :: struct {
 using rectangle: Rectangle,
	   velocity:  raylib.Vector2,
}

InputScheme :: struct {
	upButton:   raylib.KeyboardKey,
	downButton: raylib.KeyboardKey,
}

Pad :: struct {
 using rectangle: 	Rectangle,
 using input: 		InputScheme,
	   score:    	int,
	   velocity: 	raylib.Vector2,
}

players: 	[2]Pad
player1: 	^Pad
player2: 	^Pad
ball: 		Ball

InitialBallPosition: raylib.Vector2

main :: proc() {
    raylib.InitWindow(800, 450, "ODIN Pong")
    defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	player1 = &players[0]	// We have to do this here instead of above since pointers to array aren't constant yet
	player2 = &players[1]	// Careful to not put player2 := &players[1] because you will shadow and crash
	
	screenSizeX := raylib.GetScreenWidth()
	screenSizeY := raylib.GetScreenHeight()
	
	InitialBallPosition = raylib.Vector2{cast(f32)(screenSizeX/2), cast(f32)(screenSizeY/2)}
	ball.velocity = raylib.Vector2{50, 25}
	ball.centerPosition = InitialBallPosition
	ball.size = raylib.Vector2{10, 10}
	player2.size = raylib.Vector2{5, 50}
	player1.size = raylib.Vector2{5, 50}
	player2.score = 0
	player1.score = 0
	player2.velocity = raylib.Vector2{100, 100}
	player1.velocity = raylib.Vector2{100, 100}
	player1.centerPosition = raylib.Vector2{cast(f32)(0 + 5), cast(f32)(screenSizeY / 2)}
	player2.centerPosition = raylib.Vector2{cast(f32)(cast(f32)(screenSizeX) - player2.size.x - 5), cast(f32)(screenSizeY / 2)}
	player1.input = InputScheme{
		.W,
		.S,
	}
	player2.input = InputScheme{
		.I,
		.K,
	}
	
    for !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime()
		Update(dt)
		Draw()
    }
}

Update :: proc (deltaTime:f32){
	height := raylib.GetScreenHeight()
	width := raylib.GetScreenWidth()
	{ // Update players
		for _,i in players {
			player := &players[i]
			if(raylib.IsKeyDown(player.downButton)){
				// Update position
				player.centerPosition.y += cast(f32)(deltaTime * player.velocity.y)
				// Clamp on bottom edge
				if(player.centerPosition.y + (player.size.y/2) > cast(f32)height){
					player.centerPosition.y = (cast(f32)height - (player.size.y / 2))
				}
			}
			if(raylib.IsKeyDown(player.upButton)){
				// Update position
				player.centerPosition.y -= cast(f32)(deltaTime * player.velocity.y)
				// Clamp on top edge
				if(player.centerPosition.y - (player.size.y/2) < 0){
					player.centerPosition.y = player.size.y /2
				}
			}
		}
	}
	{ // Update ball
		ball.centerPosition.x += cast(f32)deltaTime * ball.velocity.x
		ball.centerPosition.y += cast(f32)deltaTime * ball.velocity.y
	}
	{ // Check collisions
		for player in players {
			isDetectBallTouchesPad := DetectBallTouchesPad(ball, player)
			if isDetectBallTouchesPad {
				ball.velocity.x *= -1
			}
		}
		isBallOnTopBottomScreenEdge := ball.centerPosition.y > cast(f32)(height) || ball.centerPosition.y < 0
		isBallOnRightScreenEdge := ball.centerPosition.x > cast(f32)(width)
		isBallOnLeftScreenEdge := ball.centerPosition.x < 0
		if isBallOnTopBottomScreenEdge {
			ball.velocity.y *= -1
		}
		if isBallOnLeftScreenEdge {
			ball.centerPosition = InitialBallPosition
			player2.score += 1
		}
		if isBallOnRightScreenEdge {
			ball.centerPosition = InitialBallPosition
			player1.score += 1
		}
	}
}

Draw :: proc (){
    raylib.BeginDrawing()
    defer raylib.EndDrawing()
    raylib.ClearBackground(raylib.BLACK)
	
	height := raylib.GetScreenHeight()
	width := raylib.GetScreenWidth()

	{ // Draw players
		for player in players {
			raylib.DrawRectangle(cast(i32)(player.centerPosition.x-(player.size.x/2)), cast(i32)(player.centerPosition.y-(player.size.y/2)), cast(i32)(player.size.x), cast(i32)(player.size.y), raylib.WHITE)
		}
	}
	{ // Draw Court Line
		LineThinkness :: 2.0
		x: 		= cast(f32)width / 2.0 // Seriously? why do i have to cast this? its a float and a division!
		from:	= raylib.Vector2{x, 5.0}
		to:		= raylib.Vector2{x, cast(f32)height - 5.0}
		
		raylib.DrawLineEx(from, to, LineThinkness, raylib.LIGHTGRAY)
	}
	{ // Draw Scores
        p1Score := strings.clone_to_cstring(fmt.tprint("", player1.score))
		defer delete(p1Score)
        p2Score := strings.clone_to_cstring(fmt.tprint("", player2.score))
		defer delete(p2Score)
		DrawText(p1Score, TextAlignment.Right, (width/2)-10, 10, 20)
		DrawText(p2Score, TextAlignment.Left,  (width/2)+10, 10, 20)
	}
	{ // Draw Ball
		raylib.DrawRectangle(cast(i32)(ball.centerPosition.x-(ball.size.x/2)), cast(i32)(ball.centerPosition.y-(ball.size.y/2)), cast(i32)(ball.size.x), cast(i32)(ball.size.y), raylib.WHITE)
	}
}

DetectBallTouchesPad :: proc (ball:Ball, pad:Pad) ->bool {
	if ball.centerPosition.x >= pad.centerPosition.x && ball.centerPosition.x <= pad.centerPosition.x+pad.size.x {
		if ball.centerPosition.y >= pad.centerPosition.y-(pad.size.y/2) && ball.centerPosition.y <= pad.centerPosition.y+pad.size.y/2 {
			return true
		}
	}
	return false
}

DrawText :: proc (text:cstring, alignment:TextAlignment, posX:i32, posY:i32, fontSize :i32){
	fontColor := raylib.LIGHTGRAY
	if alignment == .Left {
		 raylib.DrawText(text, posX, posY, fontSize, fontColor)
	} else if alignment == .Center {
		scoreSizeLeft := raylib.MeasureText(text, fontSize)
		raylib.DrawText(text, (posX - scoreSizeLeft/2), posY, fontSize, fontColor)
	} else if alignment == .Right {
		scoreSizeLeft := raylib.MeasureText(text, fontSize)
		raylib.DrawText(text, (posX - scoreSizeLeft), posY, fontSize, fontColor)
	}
}
