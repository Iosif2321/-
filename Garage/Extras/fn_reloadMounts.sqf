/*
    Author: [Håkon]
    [Description]
        Reloads mounted statics

    Arguments:
    0. <nil>

    Return Value:
    <nil>

    Scope: Clients
    Environment: Any
    Public: [No]
    Dependencies:

    Example: [] call HR_Garage_fnc_reloadMounts

    License: APL-ND
*/
#include "defines.inc"
FIX_LINE_NUMBERS()
Trace("Reloading mounts");
private _disp = findDisplay HR_Garage_IDD_Garage;
private _ctrl = _disp displayCtrl HR_Garage_IDC_ExtraMounts;
private _cat = HR_Garage_vehicles#4;
//remove old statics
{
    [HR_Garage_previewVeh, true] call EFUNC(Logistics,unload);
    deleteVehicle _x;
} forEach attachedObjects HR_Garage_previewVeh;

//remove unticked statics
private _toRemove = [];
for "_i" from 0 to (lbSize _ctrl) -1 do {
    private _class = _ctrl lbData _i;
    private _UID = _ctrl lbValue _i;
    Trace_4("Checking mount list | Index: %1 | Class: %2 | UID: %3 | Not checked: %4", _i, _class, _UID, (checkboxTextures find (_ctrl lbPicture _i)) isEqualTo 0 );
    if ( (checkboxTextures find (_ctrl lbPicture _i)) isEqualTo 0 ) then {_toRemove pushBack [_class, _UID]}; // if not checked
};
HR_Garage_Mounts = HR_Garage_Mounts - _toRemove;

//add new statics to the list
for "_i" from 0 to (lbSize _ctrl) -1 do {
    private _UID = _ctrl lbValue _i;
    if (HR_Garage_Mounts findIf {_UID isEqualTo (_x#1)} isEqualTo -1) then { //not in list
        if ( (checkboxTextures find (_ctrl lbPicture _i)) isEqualTo 1 ) then { //and checked
            HR_Garage_Mounts pushBackUnique [_ctrl lbData _i, _UID];
        };
    };
};
Trace_1("reloadMounts - Remaining mounts | %1", HR_Garage_Mounts);

//add new statics
private _lockedSeats = 0;
private _usedCapacity = 0;
{
    //load preview static onto preview vehicle
    _x params ["_class", "_vehUID"];
    private _staticData = (HR_Garage_Vehicles#4) get _vehUID;
    private _static = _class createVehicleLocal [random 100,random 100,10000 + random 10000];
    [_static, _staticData#4] call HR_Garage_fnc_setState;
    _static enableSimulation false;
    _static allowDamage false;
    _loadInfo = [HR_Garage_previewVeh, _static] call EFUNC(Logistics,canLoad);
    if (_loadInfo isEqualType 0) exitWith {};
    (_loadInfo + [true]) call EFUNC(Logistics,load);

    //get new load info
    private _nodes = _loadInfo#2;
    _usedCapacity = _usedCapacity + count _nodes;
    {_lockedSeats = _lockedSeats + count (_x#2)} forEach _nodes;

    //correct rotation bug
    private _offsetAndDir = [_static] call EFUNC(Logistics,getCargoOffsetAndDir);
    _static setVectorDir (_offsetAndDir#1);
} forEach HR_Garage_Mounts;
HR_Garage_usedCapacity = _usedCapacity;
HR_Garage_LockedSeats = _lockedSeats;
