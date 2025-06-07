params["_terminal"];
if(isNull _terminal)exitWith{};
if(!hasInterface)exitWith{[_terminal] remoteExecCall["art_fnc_addTerminalAction",0,true]};
[_terminal,0,["ACE_MainActions"],{"Артудар"},{[_terminal] call art_fnc_openTerminal},{true}] call ace_interact_menu_fnc_addActionToObject;
