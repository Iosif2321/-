params ["_object", "_actionIdVar"];

if (isNil "_object" || {isNull _object}) exitWith {};
if (!isNil {_object getVariable ["terminalActionAdded", false]}) exitWith {};

private _actionId = _object addAction ["Открыть терминал", {
    _this spawn fnc_openTerminal;
}, nil, 1.5, false, true, "", "alive _target"];

_object setVariable ["terminalActionAdded", true, true];
if (!isNil "_actionIdVar") then {
    _object setVariable [_actionIdVar, _actionId, true];
};
