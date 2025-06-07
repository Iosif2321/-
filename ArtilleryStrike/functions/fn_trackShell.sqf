params ["_shell", "_targetPos", "_markerName"];
if (isNull _shell) exitWith {};

private _marker = _markerName;
if !(getMarkerType _marker isEqualTo "") then {
    deleteMarker _marker;
}
_marker = createMarker [_markerName, getPosASL _shell];
_marker setMarkerType "mil_dot";

while { alive _shell } do {
    _marker setMarkerPos (getPosASL _shell);
    private _dist = _shell distance _targetPos;
    private _speed = vectorMagnitude (velocity _shell) max 0.1;
    uiSleep 0.2;
};
deleteMarker _marker;
