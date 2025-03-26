if (!isServer) exitWith {};

diag_log "[ZEUS SYSTEM] Скрипт запущен";

allowedSteamIDs = [
        "76561198036844993", // Iceblood
        "76561198213387391", // Yurgen
        "76561198081311236", // Hergot
        "76561198160407890", // spek2r
        "76561198339873600", // Domino
        "76561198158388837", // Vixey
        "76561198153560708", // Aveo
        "76561198855517877", // Joker
        "76561198245200164" // DED
];

fnc_assignZeus = {
    params ["_player"];

    waitUntil { !isNull _player && {getPlayerUID _player != ""} };

    private _uid = getPlayerUID _player;
    private _name = name _player;

    if (!(_uid in allowedSteamIDs)) exitWith {
        diag_log format ["[ZEUS SYSTEM] Игрок %1 (UID %2) не в списке", _name, _uid];
    };

    private _existing = getAssignedCuratorLogic _player;
    if (!isNull _existing) then {
        deleteVehicle _existing;
        diag_log format ["[ZEUS SYSTEM] Удалён старый Zeus у %1", _name];
    };

    private _zeusLogic = (createGroup sideLogic) createUnit ["ModuleCurator_F", position _player, [], 0, "NONE"];
    _zeusLogic setVariable ["Owner", _name, true];

    _player assignCurator _zeusLogic;

    private _addons = ("true" configClasses (configFile >> "CfgPatches")) apply { configName _x };
    _zeusLogic addCuratorAddons _addons;

    _zeusLogic addCuratorEditableObjects [allUnits + vehicles + allMissionObjects "", true];

    [_player, "Вы назначены Зевсом!"] remoteExecCall ["hint", _player];
    diag_log format ["[ZEUS SYSTEM] %1 (%2) назначен Zeus", _name, _uid];
};

// Назначение при старте
{
    if (isPlayer _x && {getPlayerUID _x in allowedSteamIDs}) then {
        [_x] spawn fnc_assignZeus;
    };
} forEach allPlayers;

// Назначение при входе
addMissionEventHandler ["PlayerConnected", {
    params ["_id", "_uid", "_name", "_jip", "_owner"];

    [_uid] spawn {
        params ["_uid"];
        sleep 5;
        {
            if (isPlayer _x && {getPlayerUID _x == _uid}) exitWith {
                [_x] spawn fnc_assignZeus;
            };
        } forEach allPlayers;
    };
}];

// Мониторинг каждые 5 сек
[] spawn {
    while {true} do {
        {
            if (isPlayer _x && {getPlayerUID _x in allowedSteamIDs}) then {
                private _cur = getAssignedCuratorLogic _x;
                if (isNull _cur) then {
                    diag_log format ["[ZEUS MONITOR] У %1 curator отсутствует. Переназначаем.", name _x];
                    [_x] spawn fnc_assignZeus;
                };
            };
        } forEach allPlayers;
        sleep 5;
    };
};
