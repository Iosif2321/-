if !(createDialog "MyTerminalDialog") exitWith {};

disableSerialization;
private _display = findDisplay 123456;
if (isNull _display) exitWith {};

{
    _display displayRemoveAllEventHandlers _x;
} forEach ["Unload","KeyDown"];

_display displayAddEventHandler ["Unload", {
    {
        (_this select 0) displayRemoveAllEventHandlers _x;
    } forEach ["KeyDown"];
}];
