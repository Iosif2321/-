if (isServer) then {
    // Массив разрешенных Steam ID
    private _allowedSteamIDs = [
        "76561198153560708",
        "76561198855517877",
        "76561198267661737",
        "76561198245200164" // Твой UID
    ];

    // Инициализация списка активных Зевсов (переменная на сервере)
    missionNamespace setVariable ["activeZeusList", [], true];

    // Функция назначения Зевса
    fnc_newZeus = {
        params ["_player"];
        if (isNull _player || !isPlayer _player) exitWith {};

        private _uid = getPlayerUID _player;
        if (_uid == "" || !(_uid in _allowedSteamIDs)) exitWith {
            [_player, "У вас нет прав на Зевса!"] remoteExec ["hintSilent", _player];
            diag_log format ["[ZEUS DEBUG] Отказано в доступе для %1 (UID: %2)", name _player, _uid];
        };

        if (!isNull (getAssignedCuratorLogic _player)) exitWith {
            diag_log format ["[ZEUS DEBUG] Повторный запрос Зевса от %1 (UID: %2) - пропущен", name _player, _uid];
        };

        private _cur = (createGroup sideLogic) createUnit ["ModuleCurator_F", [0,0,0], [], 0, "NONE"];
        private _addons = [];
        { _addons pushBack (configName _x); } forEach ("true" configClasses (configFile >> "CfgPatches"));
        _cur addCuratorAddons _addons;

        _player assignCurator _cur;
        _cur addCuratorEditableObjects [allMissionObjects "", false];

        // Обновляем список активных Зевсов
        private _activeZeusList = missionNamespace getVariable ["activeZeusList", []];
        _activeZeusList pushBackUnique [_player, _uid];
        missionNamespace setVariable ["activeZeusList", _activeZeusList, true];

        [_player, "Вы назначены Зевсом!"] remoteExec ["hint", _player];
        diag_log format ["[ZEUS DEBUG] Зевс назначен игроку %1 (UID: %2)", name _player, _uid];
    };

    // Автоматическое назначение Зевса для всех игроков при старте
    {
        [_x, fnc_newZeus] remoteExec ["call", 2];
    } forEach allPlayers;

    // Обработчик для новых подключающихся игроков
    addMissionEventHandler ["PlayerConnected", {
        params ["_id", "_uid", "_name", "_jip", "_owner"];
        private _player = objectFromNetId (getUserInfo _id select 0);
        if (!isNull _player) then {
            [_player, fnc_newZeus] remoteExec ["call", 2];
        };
    }];
};
