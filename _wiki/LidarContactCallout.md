When your LIDAR finds something new, a crew member tells you on the comms line where it is, like a sonar operator on a
submarine.

## What changes

Without the mod, a new contact just shows up in the Pilot tab of the OMS (your ship's Onboard Maintenance System),
with no warning, and things with no transponder (the code a ship broadcasts) never show up there at all. With the mod,
a crew member calls each one out on the comms line, with their face and name, and the call stays in the OMS's Comms
log:

> New contact, identified SE1-1234, approximate bearing 251, distance 4,000

Each call says:

- **New**, **Updated** or **Anomalous**. New the first time. Updated when your astrogator marks a contact that was
  called out with rough figures, so its exact ones are known. Anomalous for an oddity (something worth a reward of its
  own) that your astrogator can't mark: called out once, never updated.
- **identified** and its transponder code, or **UIO** when it has none, as the Pilot tab shows it.
- Its **bearing** and **distance**, the way the Pilot tab shows them. Exact for a contact your astrogator has marked.
  Otherwise **approximate**: a spot somewhere around the contact, within 20 % of its distance, and closer the more
  experienced your astrogator is. Approximate distances are rounded to 100 m.

Contacts found together come in one call, as a numbered list under *Lidar contact updates:*.

**Who calls.** Watching the LIDAR is your astrogator's job. If you have one aboard, they make every call, even off
duty (one at random if you have several). Only with no astrogator aboard does someone else in your crew call, at
random; never a passenger. With nobody aboard, there are no calls.

**What only an astrogator can do.** Anyone can notice a contact, but only an astrogator can tell an anomalous one from
the chunks of ore around it. Without an astrogator, the anomalous ones with no transponder are never called out, and
the one with a transponder is called out as a plain New contact.

**When.** The crew waits until no new contact has come for 3 seconds (the first one waits 10 seconds at most), then
calls them all at once. They don't talk over a conversation or a cutscene, and wait 8 seconds after any other comms
line, so you have time to read it.

**Where.** In a dive, in the station's simulator, and in [CombatSimulator](CombatSimulator)'s fights. Your own drones
are never called out.

## Changes how the game plays

Your crew tells you roughly where things with no transponder are as soon as the LIDAR sees them, before your
astrogator marks them: pirate ships, and the lifepods and drones of pirates. With an astrogator aboard, that includes
the oddities your astrogator can't mark at all, which the game never points out: without the mod they are just dots
on the LIDAR among the chunks. You also get a rough bearing and distance for contacts the Pilot tab lists without them.

<details>
<summary><b>SPOILER ALERT</b>: the anomalous contacts (click to show)</summary>

The Serenity torbernite crystal, the Icosahedral ice crystal, the Singularity Core the Hybrid leaves behind (a strange
ship), a red car floating in the rings, and the AI core ATLAS leaves behind (a drone that hunts rogue AI), the only one
of them with a transponder.

</details>

If something goes wrong with the LIDAR, the Pilot tab or the comms line, try again without the mod before you report a
bug to the game's developers.

## Install

See [Installing mods](Home#installing-mods).

<!-- wiki-values (checked by wiki.ps1)
game-checked: 1.93.1
LidarContactCallout/Code.gd CALLOUT_ERROR_RADIUS = 0.2 -> 20 %
LidarContactCallout/Code.gd CALLOUT_DISTANCE_STEP = 100 -> 100 m
LidarContactCallout/Code.gd CALLOUT_SETTLE = 3.0 -> 3 seconds
LidarContactCallout/Code.gd CALLOUT_MAX_WAIT = 10.0 -> 10 seconds
LidarContactCallout/Code.gd CALLOUT_AFTER_COMMS = 8.0 -> 8 seconds
LidarContactCallout/i18n/en.po LIDARCONTACTCALLOUT_CONTACT = "{status} contact, {identity}, {precision}bearing {bearing}, distance {distance}" -> New contact, identified SE1-1234, approximate bearing 251, distance 4,000
LidarContactCallout/i18n/en.po LIDARCONTACTCALLOUT_NEW = "New"
LidarContactCallout/i18n/en.po LIDARCONTACTCALLOUT_UPDATED = "Updated"
LidarContactCallout/i18n/en.po LIDARCONTACTCALLOUT_ANOMALOUS = "Anomalous"
LidarContactCallout/i18n/en.po LIDARCONTACTCALLOUT_IDENTIFIED = "identified {transponder}" -> identified
LidarContactCallout/i18n/en.po LIDARCONTACTCALLOUT_APPROXIMATE = "approximate " -> approximate
LidarContactCallout/i18n/en.po LIDARCONTACTCALLOUT_LIST = "Lidar contact updates:\n{items}" -> Lidar contact updates:
note: SE1-1234, 251 and 4,000: an example call's transponder, bearing and distance
game: UIO, what the Pilot tab shows for a contact with no transponder (hud/components/ShipOnOMSLabel.tscn placeholder)
-->
