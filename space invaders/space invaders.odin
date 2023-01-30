package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import raylib "vendor:raylib"

TextAlignment :: enum {
	Left, 
	Center,
	Right,
}

BulletCooldownSeconds 	:: 0.3
MaxNumBullets  			:: 50
MaxNumEnemies 			:: 50

Rectangle :: struct {
	centerPosition: raylib.Vector2,
	size:           raylib.Vector2,
}

InputScheme :: struct {
	leftButton:  	raylib.KeyboardKey,
	rightButton:	raylib.KeyboardKey,
	shootButton:	raylib.KeyboardKey,
}

Pad :: struct {
 using rectangle: 	Rectangle,
 using input: 		InputScheme,
	   score:    	int,
	   velocity: 	raylib.Vector2,
}

Bullet :: struct {
 using rectangle: 	Rectangle,
	   velocity: 	raylib.Vector2,
	   color:    	raylib.Color,
	   isActive: 	bool,
}

Enemy :: struct {
 using rectangle: 	Rectangle,
	   velocity: 	raylib.Vector2,
	   color:    	raylib.Color,
	   isActive: 	bool,
}

bullets: [MaxNumBullets]Bullet
enemies: [MaxNumEnemies]Enemy
player1: Pad
m_TimerBulletCooldown: f32
m_TimerSpawnEnemy: f32
numEnemiesThisLevel: int
numEnemiesToSpawn: int
numEnemiesKilled: int
numLives:= 3
IsGameOver: bool
IsWin: bool

InitialPlayerPosition: raylib.Vector2

main :: proc() {
    raylib.InitWindow(800, 450, "ODIN Space Invaders")
	defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	screenSizeX := raylib.GetScreenWidth()
	screenSizeY := raylib.GetScreenHeight()
	InitialPlayerPosition = raylib.Vector2{cast(f32)(screenSizeX / 2), cast(f32)(screenSizeY - 10)}

	{ // Set up player
		player1.size = raylib.Vector2{25, 25}
		player1.velocity = raylib.Vector2{100, 100}
		player1.centerPosition = InitialPlayerPosition
		player1.input = InputScheme{
			.A,
			.D,
			.SPACE,
		}
	}
	{ // init bullets
		for i := 0; i < MaxNumBullets; i += 1 {
			bullet := &bullets[i]
			{
				bullet.velocity = raylib.Vector2{0, 400}
				bullet.size = raylib.Vector2{5, 5}
			}
		}
	}
	{ // init enemies
		for i := 0; i < MaxNumEnemies; i += 1 {
			enemy := &enemies[i]
			{
				enemy.velocity = raylib.Vector2{0, 40}
				enemy.size = raylib.Vector2{20, 20}
				enemy.centerPosition = raylib.Vector2{rand.float32_range(0,cast(f32)screenSizeX), cast(f32)-20}
			}
		}
		numEnemiesToSpawn = 10
		numEnemiesThisLevel = 10
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

	if IsGameOver || IsWin {
		return
	}

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
		if HasHitTime(&m_TimerBulletCooldown, deltaTime) {
			if raylib.IsKeyDown(player1.shootButton) {
				for i := 0; i < MaxNumBullets; i += 1 {
					bullet := &bullets[i]
					if !bullet.isActive {
						m_TimerBulletCooldown = BulletCooldownSeconds
						bullet.isActive = true
						{
							bullet.centerPosition.x = player1.centerPosition.x
							bullet.centerPosition.y = player1.centerPosition.y + (player1.size.y / 4)
							break
						}
					}
				}
			}
		}
	}
	{ // Update active bullets
		for i := 0; i < MaxNumBullets; i += 1 {
			bullet := &bullets[i]
			// Movement
			if bullet.isActive {
				bullet.centerPosition.y -= bullet.velocity.y * deltaTime

				// Went off screen
				if bullet.centerPosition.y+(bullet.size.y/2) <= 0 {
					bullet.isActive = false
				}
			}
		}
	}
	{ // Update active enemies
		for i := 0; i < numEnemiesThisLevel; i += 1 {
			enemy := &enemies[i]
			// Movement
			if enemy.isActive {
				enemy.centerPosition.y += cast(f32)(enemy.velocity.y * deltaTime)

				// Went off screen
				if enemy.centerPosition.y-(enemy.size.y/2) >= cast(f32)(height) {
					enemy.centerPosition = raylib.Vector2{rand.float32_range(0,cast(f32)width), cast(f32)-20}
				} else {
					enemyX := enemy.centerPosition.x - (enemy.size.x / 2)
					enemyY := enemy.centerPosition.y - (enemy.size.y / 2)
					{ // bullet | enemy collision
						for j := 0; j < MaxNumBullets; j += 1 {
							bullet := &bullets[j]
							bulletX := bullet.centerPosition.x - (bullet.size.x / 2)
							bulletY := bullet.centerPosition.y - (bullet.size.y / 2)

							hasCollisionX := bulletX+bullet.size.x >= enemyX && enemyX+enemy.size.x >= bulletX
							hasCollisionY := bulletY+bullet.size.y >= enemyY && enemyY+enemy.size.y >= bulletY

							if hasCollisionX && hasCollisionY {
								bullet.isActive = false
								enemy.isActive = false
								{
									numEnemiesKilled += 1
									IsWin = numEnemiesKilled >= numEnemiesThisLevel
									break
								}
							}
						}
					}
					{ // player | enemy collision
						bulletX := player1.centerPosition.x - (player1.size.x / 2)
						bulletY := player1.centerPosition.y - (player1.size.y / 2)

						hasCollisionX := bulletX+player1.size.x >= enemyX && enemyX+enemy.size.x >= bulletX
						hasCollisionY := bulletY+player1.size.y >= enemyY && enemyY+enemy.size.y >= bulletY

						if hasCollisionX && hasCollisionY {
							enemy.isActive = false
							{
								player1.centerPosition = InitialPlayerPosition
								numLives = numLives - 1
								IsGameOver = numLives <= 0
							}
						}
					}
				}
			}
		}
	}
	{ // Spawn enemies
		canSpawn := HasHitInterval(&m_TimerSpawnEnemy, 2.0, deltaTime)
		for i := 0; i < MaxNumEnemies; i += 1 {
			enemy := &enemies[i]
			// Spawn
			if !enemy.isActive {
				if canSpawn && numEnemiesToSpawn > 0 {
					numEnemiesToSpawn = numEnemiesToSpawn - 1
					enemy.isActive = true
					{
						enemy.centerPosition = raylib.Vector2{rand.float32_range(0,cast(f32)width), cast(f32)-20}
						break
					}
				}
			}
		}
	}
}

Draw :: proc (){
	raylib.BeginDrawing()
	defer raylib.EndDrawing()
	raylib.ClearBackground(raylib.WHITE)

	height := cast(i32)(raylib.GetScreenHeight())
	width := cast(i32)(raylib.GetScreenWidth())

	{ // Draw Players
		raylib.DrawRectangle(cast(i32)(player1.centerPosition.x-(player1.size.x/2)), cast(i32)(player1.centerPosition.y-(player1.size.y/2)), cast(i32)(player1.size.x), cast(i32)(player1.size.y), raylib.BLACK)
	}
	{ // Draw the bullets
		for i := 0; i < MaxNumBullets; i += 1 {
			bullet := &bullets[i]
			if bullet.isActive {
				raylib.DrawRectangle(cast(i32)(bullet.centerPosition.x-(bullet.size.x/2)),
					cast(i32)(bullet.centerPosition.y-(bullet.size.y/2)),
					cast(i32)(bullet.size.x),
					cast(i32)(bullet.size.y),
					raylib.ORANGE)
			}
		}
	}
	{ // Draw the enemies
		for i := 0; i < MaxNumEnemies; i += 1 {
			enemy := &enemies[i]
			if enemy.isActive {
				raylib.DrawRectangle(cast(i32)(enemy.centerPosition.x-(enemy.size.x/2)),
					cast(i32)(enemy.centerPosition.y-(enemy.size.y/2)),
					cast(i32)(enemy.size.x),
					cast(i32)(enemy.size.y),
					raylib.BLUE)
			}
		}
	}
	{ // Draw Info
        lives := strings.clone_to_cstring(fmt.tprint("Lives ", numLives))
		defer delete(lives)
		DrawText(lives, TextAlignment.Left, 15, 5, 20)

		if IsGameOver {
			DrawText("Game Over", TextAlignment.Center, width/2, height/2, 50)
		}
		if IsWin {
			DrawText("You Won", TextAlignment.Center, width/2, height/2, 50)
		}
	}
}

DrawText :: proc (text:cstring, alignment:TextAlignment, posX:i32, posY:i32, fontSize :i32){
	fontColor := raylib.DARKGRAY
	if alignment == TextAlignment.Left {
		 raylib.DrawText(text, posX, posY, fontSize, fontColor)
	} else if alignment == TextAlignment.Center {
		scoreSizeLeft := raylib.MeasureText(text, fontSize)
		raylib.DrawText(text, (posX - scoreSizeLeft/2), posY, fontSize, fontColor)
	} else if alignment == TextAlignment.Right {
		scoreSizeLeft := raylib.MeasureText(text, fontSize)
		raylib.DrawText(text, (posX - scoreSizeLeft), posY, fontSize, fontColor)
	}
}

HasHitInterval :: proc(timeRemaining:^f32, resetTime:f32, deltaTime:f32) ->bool {
	timeRemaining^ -= deltaTime
	if timeRemaining^ <= 0 {
		timeRemaining^ = resetTime
		return true
	}
	return false
}

HasHitTime :: proc(timeRemaining:^f32, deltaTime:f32) ->bool {
	timeRemaining^ = timeRemaining^ - deltaTime
	return timeRemaining^ <= 0
}
