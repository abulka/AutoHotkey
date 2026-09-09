# Auto Hot Key Scripts

For Windows, I use Auto Hot Key to automate some tasks. Here are some of the scripts I use.

## Scripts

### test1.ahk

This script is used to test the functionality of Auto Hot Key. It opens a new notepad window and types "Hello World" in it.

### guilist.ahk

This script is used to automate the process of selecting a value from a list of values in a GUI window. It opens a GUI window with a list of values, and allows the user to select a value from the list.

### bar_cheat.ahk

This script is used to automate the process of cheating in the "Beyond All Reason" game. It opens a GUI window with a treeview list of possible objects to create.

#### Requirements

- [AutoHotkey v2.0](https://www.autohotkey.com/) installed

#### How to Run

1. Double-click `bar_cheat.ahk` (or right-click it and choose "Run Script"). This runs the script in the background with no visible window.
2. In the game, press **Enter** to open the chat/console window. This is required — the script types the cheat code into it.
3. With the game running, press **Alt+C** to open the cheat code GUI.
4. Select a cheat from the treeview, adjust the amount if needed, then press **Enter** (or click "Paste Code" / double-click the entry). The GUI closes and the cheat command is typed into the game's chat and submitted.
5. Press **Escape** in the GUI to close it without pasting.
6. Stop the script by right-clicking the green AutoHotkey "H" icon in the system tray and choosing "Exit".

Important: cheating requires the game to have cheats enabled — the host must run `/cheat` first (there's a "Cheat ON" entry in the Game Commands category).

Notes:

- Recent cheats are remembered in `bar_cheats_recent.txt` and shown in a "Recent" category at the top of the tree.
- The treeview expand/collapse state is saved in `bar_treeview_state.txt`.
- Unit preview images are loaded from the `unit_images/` folder when a selected unit has a matching image.
- `bar_cheats.txt` can be edited (even while the script is running); the list reloads automatically next time the GUI is opened.

#### Example Codes

```
Units
    Constructors|/give 10 armck 0
    Construction Kbot|/give 10 armack 0
    Spider|/give 10 armsptk 0
    Titan (Bantha)|/give 10 armbanth 0
    Butler - Fast Assist / Repair Bot|/give 10 armfark 0
    DUMMYX TEST UNIT|/give 10 armcom 0
Buildings
    Construction Turret|/give 1 armnanotc 0
    Tech 2 Lab|/give 1 armalab 0
    Tech 3 Lab|/give 1 armshltx 0
    Advanced Radar|/give 1 armarad 0
    Shield|/give 1 armgate 0
Weapons
    Anti Missile (Ferret)|/give 1 armferret 0
    Flak|/give 1 armflak 0
    Big Bertha|/give 1 armbrtha 0
    Mobile Tachyon Weapon|/give 2 armmanni 0
    Ragnarok - Rapid-Fire Long-Range Plasma Cannon|/give 1 armvulc 0
Aircraft
    Strategic Bomber|/give 20 armpnix 0
    Atomic Bomber|/give 2 armliche 0
    Advanced Construction Aircraft|/give 10 armaca 0
Game Commands
    Cheat ON|/cheat
    Infinite resources|/give resourcecheat 0
    Toggle Visibility|/globallos 0
    God mode control any unit|/godmode
    No cost ON|/nocost
    No cost OFF|/nocost 0
```

