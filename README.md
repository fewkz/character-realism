# Character Realism

Fork of [Character Realism](https://github.com/MaximumADHD/Character-Realism) by [MaximumADHD](https://github.com/MaximumADHD)
modified to be more extensible.

## What is this?

*Realism* is a character enhancement system for Roblox designed to be adaptive and minimally invasive to existing game code. It allows players to see their avatar's body in first person and look around with their head in third person. It additionally override's Roblox's default walking sound with a set of material-based walking sounds. 

## Features

- Compatible with real-time avatar scaling and HumanoidDescription changes.
- Interpolated 100% on the client, no snapping or lag.
- Supports both R6 and R15 avatars.

## Installation

You can download a build with the server and client code included from [GitHub Releases](https://github.com/fewkz/character-realism/releases)

You can also add realism to your project via [Wally](https://wally.run/) by adding the following dependencies.
```lua
CharacterRealismClient = "fewkz/character-realism-client@0.1.3"
CharacterRealismServer = "fewkz/character-realism-server@0.1.0"
```

## Licensing

*Realism* is licensed under v2.0 of the Mozilla Public License. The intent of using this license is to allow the system to be used commercially in Roblox games for free without requiring the entire source code of the game to be disclosed. However, any improvements that you make to the system itself which could benefit others using it should be publicly disclosed under the same conditions. You must also provide credit to me (CloneTrooper1019) somewhere in your game if you use this system. This can be either the description or an in-game credits feature. Whatever suits you best :)!
