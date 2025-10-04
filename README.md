<div align="center">
  
# 🍋 Lemonade

<a href="https://github.com/Jaezmien/Lemonade/releases/latest">
	<img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/Jaezmien/Lemonade?color=%23ffff00&style=for-the-badge">
</a>

> A NotITG External handler

</div>

# Requirements

This addon requries you to have a theme that is using Overlays. If you're using the included [Simply Love theme for NotITG](https://github.com/TaroNuke/Simply-Love-NotITG-ver.-), you should be good already.

# Instructions

1. Copy the contents of [Screens](Screens/) and [Scripts](Scripts/) to your theme directory. On new installs, there should be no merged files.

2. Go to `Screens/Overlay/default.xml` and insert `Lemonade.xml` to the end of the ActorFrame.

Example:

```xml
<ActorFrame
	OnCommand="effectperiod,0/1;luaeffect,Update"
	UpdateCommand="%function(self) stitch('lua.event').Update(self) end"
	OverlayReadyMessageCommand="%function(self) stitch.RequireEnv('lua.setup', {self = self}) end" >
	<children>
		<Layer File="Aft" />
		<Layer File="Death" />
		<Layer File="Console"/>
		<Layer File="ViewGC" />

		<Layer File="Lemonade.xml"/> <!-- Insert Lemonade.xml here -->
	</children>

</ActorFrame>
```

# Scripts

- [Discord RPC](https://github.com/Jaezmien/Lemonade-DiscordRPC)
- [Song Info for OBS](https://github.com/Jaezmien/Lemonade-OBSSongInfo)
- [Spellcard for OBS](https://github.com/Jaezmien/Lemonade-OBSSpellcard)
