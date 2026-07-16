<div align="center">
  <img alt="Icon" src="https://github.com/user-attachments/assets/ccefa1dc-f593-4eff-bd32-7f12be8f23d2" width="128" />

  # Gyrobots
  
  **Tilt, Jump, and Share the Chaos to Beat the Clock!**
</div>

## About

**Gyrobots** is a local multiplayer iOS game that requires two players to share control of a single robot to complete courses before the timer runs out. Roles are divided between the players: one steers the robot using gyroscope tilt controls, while the other manages jumping and collects scattered bolts to gain speed boosts. To determine the visual theme of the course, the app retrieves the players' GPS coordinates and queries OpenStreetMap to style the environment (such as a city or forest) based on their real-world surroundings. Local multiplayer connectivity is established over Wi-Fi using Apple's local networking APIs. The game is built using SwiftUI and SpriteKit, which handle the user interface, 2D physics, slopes, and obstacle collisions.

## Building from Source

1. Clone this repository:
```bash
git clone https://github.com/JNR306/Gyrobots.git
```
2. Initialize the local configuration:
```bash
cp Config/Local.example.xcconfig Config/Local.xcconfig
```
3. Open `Config/Local.xcconfig` and configure your `TEAM_ID` and `BASE_BUNDLE_ID`:
```xcconfig
TEAM_ID = ABCD123456
BASE_BUNDLE_ID = com.your.organization
```
5. Open `Gyrobots.xcodeproj` in Xcode and execute `Cmd + R` to build.
