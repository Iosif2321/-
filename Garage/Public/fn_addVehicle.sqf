/*
    Author: [Håkon]
    [Description]
        Tries to add a vehicle to the garage, with feedback transmited back to the client

    Arguments:
    0. <Object> Vehicle to add
    1. <Int>    ClientID
    2. <String> Lock UID
    3. <Object> Player trying to add the vehicle

    Return Value:
    <Bool> Successfully added vehicle

    Scope: Server
    Environment: Any
    Public: [Yes]
    Dependencies: TeamPlayer, FactionGet(reb,"name"), Invaders, Occupants, HR_Garage_Sources, HR_Garage_Vehicles

    Example: [cursorObject, clientOwner, call HR_Garage_dLock, _player] remoteExecCall ["HR_Garage_fnc_addVehicle",2];

    License: MIT / (APL-ND) the license switch is noted in the code
*/
params [ ["_vehicle", objNull, [objNull]], ["_client", 2, [0]], ["_lockUID", ""], ["_player", objNull, [objNull]] ];
#include "defines.inc"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("called on client, this is a server only function") };
if (isNil "HR_Garage_Vehicles") then { [] call HR_Garage_fnc_initServer };
private _class = typeOf _vehicle;

//validate input
if (isNull _vehicle) exitWith { ["STR_HR_Garage_Feedback_addVehicle_Null"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };
if (!alive _vehicle) exitWith { ["STR_HR_Garage_Feedback_addVehicle_Destroyed"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };
if (locked _vehicle > 1) exitWith { ["STR_HR_Garage_Feedback_addVehicle_Locked"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };
if (player isNotEqualTo vehicle player) exitWith { ["STR_HR_Garage_Feedback_addVehicle_inVehicle"] remoteExec ["HR_Garage_fnc_Hint"] ; false };
if (!isnull _player && (_player distance _vehicle > 25)) exitWith {["STR_HR_Garage_Feedback_addVehicle_Distance"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };

    //Towing
if !((_vehicle getVariable ["SA_Tow_Ropes",objNull]) isEqualTo objNull) exitWith {["STR_HR_Garage_Feedback_addVehicle_SATow"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };

    //crewed
private _exit = false;
if ( ( {alive _x} count (crew _vehicle) ) > 0) then { _exit = true };
{ if ( ( {alive _x} count (crew _x) ) > 0) exitWith {_exit = true} } forEach attachedObjects _vehicle;
if (_exit) exitWith { ["STR_HR_Garage_Feedback_addVehicle_Crewed"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };

    // valid vehicle for garage
private _cat = [_class] call HR_Garage_fnc_getCatIndex;
if (_cat isEqualTo -1) exitWith { ["STR_HR_Garage_Feedback_addVehicle_GenericFail"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };
if (_cat isEqualTo 2 && {!(call HR_Garage_Cnd_canAccessAir)}) exitWith {["STR_HR_Garage_Feedback_addVehicle_airBlocked"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };

    //cap block
private _capacity = 0;
{ _capacity = _capacity + count _x } forEach HR_Garage_Vehicles;

private _countStatics = {_x isKindOf "StaticWeapon"} count (attachedObjects _vehicle);
if ((call HR_Garage_VehCap - _capacity) < (_countStatics + 1)) exitWith { ["STR_HR_Garage_Feedback_addVehicle_Capacity"] remoteExec ["HR_Garage_fnc_Hint", _client]; false };//HR_Garage_VehCap is defined in config.inc

//_this is vehicle
private _unloadAceCargo = {
    {
        if !(_x isEqualType objNull) then { continue };
        if (typeOf _x in ["ACE_Wheel", "ACE_Track"]) then { continue };
        [_x, _this] call ace_cargo_fnc_unloadItem;
    } forEach (_this getVariable ["ace_cargo_loaded", []]);
};

//---------------------------------------------------------|
// Everything above this line is under the license: MIT    |
// Everything under this line is under the license: APL-ND |
//---------------------------------------------------------|

//add vehicle
if (_vehicle getVariable ["HR_Garage_Garaging", false]) exitWith {};
_vehicle setVariable ["HR_Garage_Garaging", true];

private _addVehicle = {
    //check if compatible with garage
    private _class = typeOf _this;
    private _cat = [_class] call HR_Garage_fnc_getCatIndex;
    if (_cat isEqualTo -1) exitWith {};
    _catsRequiringUpdate pushBackUnique _cat;

    private _source = [
        [_this] call HR_Garage_fnc_isAmmoSource
        ,[_this] call HR_Garage_fnc_isFuelSource
        ,[_this] call HR_Garage_fnc_isRepairSource
    ];
    private _sourceIndex = _source find true;

    private _stateData = [_this] call HR_Garage_fnc_getState;
    private _customisation = [_this] call BIS_fnc_getVehicleCustomization;

    _this call _unloadAceCargo;

    deleteVehicle _this;

    //Add vehicle to garage
    private _vehUID = [] call HR_Garage_fnc_genVehUID;
    (HR_Garage_Vehicles#_cat) set [_vehUID, [cfgDispName(_class), _class, _lockUID, "", _stateData, _lockName, _customisation]];

    //register vehicle as a source
    if (_sourceIndex != -1) then {
        (HR_Garage_Sources#_sourceIndex) pushBack _vehUID;
        [_sourceIndex] call HR_Garage_fnc_declairSources;
    };

    Info_6("By: %1 [%2] | Type: %3 | Vehicle ID: %4 | Lock: %5 | Source: %6", name _player, getPlayerUID _player, cfgDispName(_class), _vehUID, _locking, _sourceIndex);
};

private _locking = if (_lockUID isEqualTo "") then {false} else {true};
private _lockName = if (_locking) then { name _player } else { "" };
private _catsRequiringUpdate = [];
{
    detach _x;
    _x call _addVehicle;
} forEach attachedObjects _vehicle;
_vehicle call _addVehicle;

//refresh category for active users
private _refreshCode = {
    #include "defines.inc"
    FIX_LINE_NUMBERS()
    private _disp = findDisplay HR_Garage_IDD_Garage;
    private _cats = _this apply { HR_Garage_Cats#_x };
    {
        if (ctrlEnabled _x) then {
            [_x, _this#_forEachIndex] call HR_Garage_fnc_reloadCategory;
        };
    } forEach _cats;
    call HR_Garage_fnc_updateVehicleCount;
};
[ _catsRequiringUpdate, _refreshCode ] remoteExecCall ["call", HR_Garage_Users];

["STR_HR_Garage_Feedback_addVehicle_Success", [cfgDispName(_class)] ] remoteExec ["HR_Garage_fnc_Hint", _client];
true;
