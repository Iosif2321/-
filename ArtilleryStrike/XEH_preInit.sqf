art_fnc_addTerminalAction = compile preprocessFileLineNumbers "ArtilleryStrike\functions\fn_addTerminalAction.sqf";
art_fnc_openTerminal = compile preprocessFileLineNumbers "ArtilleryStrike\functions\fn_openTerminal.sqf";
art_fnc_fireShell = compile preprocessFileLineNumbers "ArtilleryStrike\functions\fn_fireShell.sqf";
art_fnc_trackShell = compile preprocessFileLineNumbers "ArtilleryStrike\functions\fn_trackShell.sqf";
art_fnc_collectAmmo = compile preprocessFileLineNumbers "ArtilleryStrike\functions\fn_collectAmmo.sqf";
art_ammoList = {getNumber(_this>>"caliber")>60} call art_fnc_collectAmmo;
art_dispersion = 0.05;
