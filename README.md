# Character Realism

Fork of [Character Realism](https://github.com/MaximumADHD/Character-Realism) by
[MaximumADHD](https://github.com/MaximumADHD) modified to be more extensible.

## What is this?

_Realism_ is a character enhancement system for Roblox designed to be adaptive
and minimally invasive to existing game code. It allows players to see their
avatar's body in first person and look around with their head in third person.
It additionally override's Roblox's default walking sound with a set of
material-based walking sounds.

## Features

- Compatible with real-time avatar scaling and HumanoidDescription changes.
- Interpolated 100% on the client, no snapping or lag.
- Supports both R6 and R15 avatars.

## Installation

You can also add realism to your project via [Wally](https://wally.run/) by
adding the following dependencies.

```lua
CharacterRealismClient = "fewkz/character-realism-client@0.2.1"
CharacterRealismServer = "fewkz/character-realism-server@0.1.1"
```

You then need to start the realism client and server with configuration. For
examples of configuring realism, see `model.client.lua` and `model.server.lua`.

You can also download a model with client and server scripts that already
configure realism from
[GitHub Releases](https://github.com/fewkz/character-realism/releases) or
[Roblox Library](https://www.roblox.com/library/11082524851/Character-Realism),
you just need to put `RealismServer` in `ServerScriptService` and
`RealismClient` in `StarterPlayerScripts`. You can then change the configuration
in the scripts yourself. This model is build from `model.project.json`.

## Demo

The root of this project contains a demo Rojo project for testing out character
realism. This demo is available on Roblox at
https://roblox.com/games/11058600821

This demo project requires [Plasma](https://github.com/evaera/plasma), an
immediate mode UI library, for controlling the character realism configuration.
You should install plasma using Git like so:

```
git clone --depth 1 --branch v0.4.2 https://github.com/evaera/plasma.git plasma
```

## Licensing

_fewkz/character-realism_ is licensed under v2.0 of the Mozilla Public License.
The intent of using this license is to allow the system to be used commercially
in Roblox games for free without requiring the entire source code of the game to
be disclosed. However, any improvements that you make to the system itself which
could benefit others using it should be publicly disclosed under the same
conditions. You must include a reference and credits to this project
(fewkz/character-realism), and the original "Character Realism" project by
MaximumADHD somewhere in your game. This can be either the description or an
in-game credits feature. I'd recommend something like: "Uses
fewkz/character-realism, fork of Character Realism by MaximumADHD"
