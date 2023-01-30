package main

import "core:fmt"
import "core:intrinsics"
import "core:strings"
import "core:math"
import "core:math/rand"
import raylib "vendor:raylib"

BoardWidthInBricks  :: 12
BoardHeightInBricks :: 13
BrickWidthInPixels  :: 64
BrickHeightInPixels :: 24

BrickOffsetX :: 16
BrickOffsetY :: 16

NumBrickTypes :: 4

TextAlignment :: enum {
	Left, 
	Center,
	Right,
}

CollisionFace :: enum {
	None,
	Left,
	Top,
	Right,
	Bottom,
}

Brick :: struct {
	typeOf:  int,
	isAlive: bool,
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
	leftButton:  	raylib.KeyboardKey,
	rightButton:	raylib.KeyboardKey,
}

Pad :: struct {
 using rectangle: 	Rectangle,
 using input: 		InputScheme,
	   score:    	int,
	   velocity: 	raylib.Vector2,
}

player1: 	Pad
bricks: 	[BoardWidthInBricks][BoardHeightInBricks]Brick
ball: 		Ball

InitialBallPosition: raylib.Vector2
InitialBallVelocity: raylib.Vector2

main :: proc() {
    raylib.InitWindow(800, 450, "ODIN Breakout")
    defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	SetupGame()
	
    for !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime()
		Update(dt)
		Draw()
    }
}


SetupGame :: proc() {
	screenSizeX := raylib.GetScreenWidth()
	screenSizeY := raylib.GetScreenHeight()

	{ // Setup bricks
		for i := 0; i < BoardWidthInBricks; i += 1 {
			for j := 0; j < BoardHeightInBricks; j += 1 {
				bricks[i][j].typeOf = cast(int)(rand.uint64()%4)
				bricks[i][j].isAlive = true
			}
		}
	}
	{ // Set up ball
		InitialBallPosition = raylib.Vector2{cast(f32)(screenSizeX / 2), cast(f32)(screenSizeY - 20)}
		InitialBallVelocity = raylib.Vector2{50, -25}
		ball.velocity = InitialBallVelocity
		ball.centerPosition = InitialBallPosition
		ball.size = raylib.Vector2{10, 10}
	}
	{ // Set up player
		player1.size = raylib.Vector2{50, 5}
		player1.velocity = raylib.Vector2{100, 100}
		player1.centerPosition = raylib.Vector2{cast(f32)(screenSizeX / 2), cast(f32)(screenSizeY - 10)}
		player1.input = InputScheme{
			.A,
			.D,
		}
	}
}

Update :: proc (deltaTime:f32){
	height := raylib.GetScreenHeight()
	width := raylib.GetScreenWidth()
	collisionFace := CollisionFace.None

	{ // Update Player
		if raylib.IsKeyDown(player1.rightButton) {
			// Update position
			player1.centerPosition.x += (deltaTime * player1.velocity.x)
			// Clamp on right edge
			if player1.centerPosition.x+(player1.size.x/2) > cast(f32)(width) {
				player1.centerPosition.x = cast(f32)(width) - (player1.size.x / 2)
			}
		}
		if raylib.IsKeyDown(player1.leftButton) {
			// Update position
			player1.centerPosition.x -= (deltaTime * player1.velocity.x)
			// Clamp on left edge
			if player1.centerPosition.x-(player1.size.x/2) < 0 {
				player1.centerPosition.x = (player1.size.x / 2)
			}
		}
	}
	{ // Update ball
		ball.centerPosition.x += deltaTime * ball.velocity.x
		ball.centerPosition.y += deltaTime * ball.velocity.y
	}
	// Collisions
	{ // ball boundary collisions
		isBallOnBottomScreenEdge := ball.centerPosition.y > cast(f32)(height)
		isBallOnTopScreenEdge := ball.centerPosition.y < cast(f32)(0)
		isBallOnLeftRightScreenEdge := ball.centerPosition.x > cast(f32)(width) || ball.centerPosition.x < cast(f32)(0)
		if isBallOnBottomScreenEdge {
			ball.centerPosition = InitialBallPosition
			ball.velocity = InitialBallVelocity
		}
		if isBallOnTopScreenEdge {
			ball.velocity.y *= -1
		}
		if isBallOnLeftRightScreenEdge {
			ball.velocity.x *= -1
		}
	}
	{ // ball brick collisions
		loop: for i := 0; i < BoardWidthInBricks; i += 1 {
			for j := 0; j < BoardHeightInBricks; j += 1 {
				brick := &bricks[i][j]
				if !brick.isAlive {
					continue
				}

				// Coords
				brickX := cast(f32)(BrickOffsetX + (i * BrickWidthInPixels))
				brickY := cast(f32)(BrickOffsetY + (j * BrickHeightInPixels))

				// Ball position
				ballX := ball.centerPosition.x - (ball.size.x / 2)
				ballY := ball.centerPosition.y - (ball.size.y / 2)

				// Center Brick
				brickCenterX := brickX + (BrickWidthInPixels / 2)
				brickCenterY := brickY + (BrickHeightInPixels / 2)

				hasCollisionX := ballX+ball.size.x >= brickX && brickX+BrickWidthInPixels >= ballX
				hasCollisionY := ballY+ball.size.y >= brickY && brickY+BrickHeightInPixels >= ballY

				if hasCollisionX && hasCollisionY {
					brick.isAlive = false

					// Determine which face of the brick was hit
					ymin := max(brickY, ballY)
					ymax := min(brickY+BrickHeightInPixels, ballY+ball.size.y)
					ysize := ymax - ymin
					xmin := max(brickX, ballX)
					xmax := min(brickX+BrickWidthInPixels, ballX+ball.size.x)
					xsize := xmax - xmin
					if xsize > ysize && ball.centerPosition.y > brickCenterY {
						collisionFace = CollisionFace.Bottom
					} else if xsize > ysize && ball.centerPosition.y <= brickCenterY {
						collisionFace = CollisionFace.Top
					} else if xsize <= ysize && ball.centerPosition.x > brickCenterX {
						collisionFace = CollisionFace.Right
					} else if xsize <= ysize && ball.centerPosition.x <= brickCenterX {
						collisionFace = CollisionFace.Left
					} else {
						// Could assert or panic here
					}

					break loop
				}
			}
		}
	}
	{ // Update ball after collision
		if collisionFace != CollisionFace.None {
			hasPositiveX := ball.velocity.x > 0
			hasPositiveY := ball.velocity.y > 0
			if  (collisionFace == .Top    && hasPositiveX  && hasPositiveY) ||
				(collisionFace == .Top    && !hasPositiveX && hasPositiveY) ||
				(collisionFace == .Bottom && hasPositiveX  && !hasPositiveY) ||
				(collisionFace == .Bottom && !hasPositiveX && !hasPositiveY) {
				ball.velocity.y *= -1
			}
			if  (collisionFace == .Left  && hasPositiveX  && hasPositiveY) ||
				(collisionFace == .Left  && hasPositiveX  && !hasPositiveY) ||
				(collisionFace == .Right && !hasPositiveX && hasPositiveY) ||
				(collisionFace == .Right && !hasPositiveX && !hasPositiveY) {
				ball.velocity.x *= -1
			}
		}
	}
	{ // Update ball after pad collision
		if DetectBallTouchesPad(&ball, &player1) {
			previousVelocity := ball.velocity
			distanceX := ball.centerPosition.x - player1.centerPosition.x
			percentage := distanceX / (player1.size.x / 2)
			ball.velocity.x = InitialBallVelocity.x * percentage
			ball.velocity.y *= -1
			newVelocity := vector2_scale(vector2_normalize(ball.velocity), (vector2_length(previousVelocity) * 1.1))
			ball.velocity = newVelocity
		}
	}
	{ // Detect all bricks popped
		hasAtLeastOneBrick := false
		loop2: for i := 0; i < BoardWidthInBricks; i += 1 {
			for j := 0; j < BoardHeightInBricks; j += 1 {
				brick := bricks[i][j]
				if brick.isAlive {
					hasAtLeastOneBrick = true
					break loop2
				}
			}
		}
		if !hasAtLeastOneBrick {
			SetupGame()
		}
	}
}

Draw :: proc (){
	raylib.BeginDrawing()
	defer raylib.EndDrawing()
	raylib.ClearBackground(raylib.BLACK)

	{ // Draw alive bricks
		for i := 0; i < BoardWidthInBricks; i += 1 {
			for j := 0; j < BoardHeightInBricks; j += 1 {
				if !bricks[i][j].isAlive {
					continue
				}

				raylib.DrawRectangle(cast(i32)(BrickOffsetX+(i*BrickWidthInPixels)), cast(i32)(BrickOffsetY+(j*BrickHeightInPixels)), BrickWidthInPixels, BrickHeightInPixels, TypeToColor(bricks[i][j].typeOf))
			}
		}
	}
	{ // Draw Players
		raylib.DrawRectangle(cast(i32)(player1.centerPosition.x-(player1.size.x/2)), cast(i32)(player1.centerPosition.y-(player1.size.y/2)), cast(i32)(player1.size.x), cast(i32)(player1.size.y), raylib.WHITE)
	}
	{ // Draw Ball
		raylib.DrawRectangle(cast(i32)(ball.centerPosition.x-(ball.size.x/2)), cast(i32)(ball.centerPosition.y-(ball.size.y/2)), cast(i32)(ball.size.x), cast(i32)(ball.size.y), raylib.WHITE)
	}
}

DetectBallTouchesPad :: proc(ball:^Ball, pad:^Pad) ->bool {
	ballX := ball.centerPosition.x - (ball.size.x / 2)
	ballY := ball.centerPosition.y - (ball.size.y / 2)
	padX := pad.centerPosition.x - (pad.size.x / 2)
	padY := pad.centerPosition.y - (pad.size.y / 2)
	if ballY+(ball.size.y/2) >= padY && ballX >= padX && ballX <= padX+pad.size.x {
		return true
	}
	return false
}

TypeToColor :: proc(typeOf:int) ->raylib.Color {
	switch typeOf {
		case 0: return raylib.WHITE
		case 1: return raylib.RED
		case 2: return raylib.GREEN
		case 3: return raylib.BLUE
	}
	return raylib.Color{}
}

vector2_length :: proc(v: raylib.Vector2) -> f32 { // not sure why we aren't importing ext/raymath
    return intrinsics.sqrt((v.x*v.x) + (v.y*v.y))	// Why did i have to qualify this. i wanted it in the global namespace
}

vector2_scale :: proc(v: raylib.Vector2, scale: f32) -> raylib.Vector2 {
    return raylib.Vector2{v.x*scale, v.y*scale}
}

vector2_normalize :: proc(v: raylib.Vector2) -> raylib.Vector2 {
    return vector2_scale(v, 1/vector2_length(v))
}
