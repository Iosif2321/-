params ["_pos", "_dir", "_shellType", "_velocity"];
if (isNil "_pos" || isNil "_dir" || isNil "_shellType" || { _shellType isEqualTo "" } || isNil "_velocity") exitWith {};
if !(isClass (configFile >> "CfgAmmo" >> _shellType)) exitWith {};

private _shell = _shellType createVehicle _pos;
if (isNull _shell) exitWith {};

_shell setPosASL _pos;
_shell setVectorDirAndUp [_dir, [0,0,1]];
_shell setVelocity (_dir vectorMultiply _velocity);
