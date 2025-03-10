if (isServer) then {
    private _allowedSteamIDs = ["76561198153560708", "76561198855517877", "76561198267661737"];

    fnc_assignZeus = {
        params ["_player"];
        if (isNull _player || !isPlayer _player) exitWith {};
        private _uid = getPlayerUID _player;
        if (_uid == "") exitWith { diag_log "[ZEUS DEBUG] UID не определен"; };
        if !(_uid in _allowedSteamIDs) exitWith { diag_log format ["[ZEUS DEBUG] Отказано в доступе для %1 (UID: %2)", name _player, _uid]; };
        if (!isNull (getAssignedCuratorLogic _player)) exitWith { diag_log format ["[ZEUS DEBUG] Зевс уже назначен игроку %1 (UID: %2)", name _player, _uid]; };
        private _cur = (createGroup [sideLogic, true]) createUnit ["ModuleCurator_F", [0,0,0], [], 0, "NONE"];
        private _addons = ("true" configClasses (configFile >> "CfgPatches")) apply {configName _x};
        _cur addCuratorAddons _addons;
        _player assignCurator _cur;
        _cur addCuratorEditableObjects [allMissionObjects "", false];
        ["Вы назначены Зевсом!"] remoteExecCall ["hint", _player];
        diag_log format ["[ZEUS DEBUG] Зевс назначен игроку %1 (UID: %2)", name _player, _uid];
    };

    addMissionEventHandler ["PlayerConnected", {
        params ["_id", "_uid", "_name", "_jip", "_owner"];
        private _player = objectFromNetId (getUserInfo _id select 3);
        if (isNull _player) exitWith { diag_log "[ZEUS DEBUG] Игрок не найден при подключении"; };
        [_player] spawn fnc_assignZeus;
    }];

    { if (isPlayer _x) then { [_x] spawn fnc_assignZeus; }; } forEach allPlayers;

    [] spawn {
        waitUntil {time > 0};
        diag_log "[ZEUS DEBUG] Мониторинг Зевса запущен";

        while {true} do {
            private _zeusPlayersList = [];
            {
                if (isPlayer _x && !isNull _x) then {
                    private _curator = getAssignedCuratorLogic _x;
                    if (!isNull _curator) then {
                        // Временно убираем curatorCamera для теста
                        _zeusPlayersList pushBack [_x, time];
                        diag_log format ["[ZEUS DEBUG] %1 временно добавлен (без проверки камеры)", name _x];
                    };
                };
            } forEach allPlayers;

            private _displayList = [];
            private _zeusHolders = [];
            {
                _x params ["_player", "_lastActiveTime"];
                if (!isNull _player && {isPlayer _player}) then {
                    private _uid = getPlayerUID _player;
                    private _name = name _player;
                    private _entry = format ["%1 (SteamID: %2)", _name, _uid];
                    if ((time - _lastActiveTime) <= 10) then {
                        if !(_entry in _displayList) then {
                            _displayList pushBack _entry;
                        };
                    };
                    if (!isNull (getAssignedCuratorLogic _player)) then {
                        _zeusHolders pushBack _player;
                    };
                };
            } forEach _zeusPlayersList;

            private _message = "";
            if (_displayList isEqualTo []) then {
                _message = "Нет игроков, использующих Зевс сейчас или недавно";
                diag_log "[ZEUS DEBUG] Нет активных или недавно бывших в Зевсе игроков";
            } else {
                _message = "Активные/недавние Зевсы:\n" + (_displayList joinString "\n");
                diag_log format ["[ZEUS DEBUG] Активные/недавние Зевсы: %1", _displayList joinString ", "];
            };

            if !(_zeusHolders isEqualTo []) then {
                [_message] remoteExecCall ["hint", _zeusHolders];
            };

            sleep 10;
        };
    };
};