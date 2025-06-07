params ["_container"];
if (isNil "_container" || {isNull _container}) exitWith {[]};

private _ammoTypes = [];
{
    private _ammo = getMagazineAmmoCargo _x;
    if !(_ammoTypes findIf { _x isEqualTo _ammo } > -1) then {
        _ammoTypes pushBack _ammo;
    };
} forEach (magazinesAmmoCargo _container);

_ammoTypes
