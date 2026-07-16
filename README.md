<div align="center">
  <img alt="Icon" src="https://github.com/user-attachments/assets/ccefa1dc-f593-4eff-bd32-7f12be8f23d2" width="128" />

  # Gyrobots
  
  **Tilt, Jump, and Share the Chaos to Beat the Clock!**

</div>

<div align="center">
  <table>
  <tr>
    <td width="852" valign="top">
      <img width="852" height="394" alt="IMG_5056" src="https://github.com/user-attachments/assets/110a475c-e792-4fef-a8ad-38d5282dd8e6" />
    </td>
    <td width="852" valign="top">
      <img width="852" height="394" alt="IMG_5063" src="https://github.com/user-attachments/assets/529972df-4000-4264-8ff7-55de108a8346" />
    </td>
  </tr>
  </table>
</div>


https://github.com/user-attachments/assets/d1ebf19b-b110-4904-8cc7-64f421a2bf79

## About

**Gyrobots** is a local multiplayer iOS game that requires two players to share control of a single robot to complete courses before the timer runs out. Roles are divided between the players: one steers the robot using gyroscope tilt controls, while the other manages jumping and collects scattered bolts to gain speed boosts. To determine the visual theme of the course, the app retrieves the players' GPS coordinates and queries OpenStreetMap to style the environment (such as a city or forest) based on their real-world surroundings. Local multiplayer connectivity is established over Wi-Fi using Apple's local networking APIs. The game is built using SwiftUI and SpriteKit, which handle the user interface, 2D physics, slopes, and obstacle collisions.

[Gyrobots Gameplay Instructions.pdf](https://github.com/user-attachments/files/30103432/Gyrobots.Gameplay.Instructions.pdf)

<div align="center">
  <table>
  <tr>
    <td width="852" valign="top">
      <img width="852" height="394" alt="IMG_5059" src="https://github.com/user-attachments/assets/27821ae2-93fb-46f5-8d82-6f204d12274b" />
    </td>
    <td width="852" valign="top">
      <img width="852" height="394" alt="IMG_5064" src="https://github.com/user-attachments/assets/f5d437f1-5907-457b-902f-e43555bb5772" />
    </td>
  </tr>
  </table>
</div>

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
