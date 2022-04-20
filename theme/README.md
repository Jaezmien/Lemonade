<div align="center">
  
# Lemonade Theme Addon

> A theme addon to easily handle NotITG Externals

</div>

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

		<Layer File="Lemonade"/> <!-- Insert Lemonade.xml here -->
    </children>

</ActorFrame>
```
