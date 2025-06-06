params["_console","_board"];
if(isNull _console || isNull _board)exitWith{};
if(!hasInterface)exitWith{[_console,_board] remoteExecCall["tb_fnc_addConsoleAction",0,true]};
[_console,0,["ACE_MainActions"],{"Edit"},{[_board] call tb_fnc_openInput},{true}] call ace_interact_menu_fnc_addActionToObject;
