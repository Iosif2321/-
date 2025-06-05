diag_log "=== INIT SERVER ЗАПУЩЕН ===";

private _dbResult = "extDB3" callExtension "9:ADD_DATABASE:arma3_db";
if (_dbResult isEqualTo "[1]") then {
    diag_log "extDB3: Успешно подключено к базе данных [arma3_db]";
} else {
    diag_log format ["extDB3: Ошибка подключения к базе данных: %1", _dbResult];
};

private _protoResult = "extDB3" callExtension "9:ADD_DATABASE_PROTOCOL:arma3_db:SQL_CUSTOM:0:sql_custom.ini";
if (_protoResult isEqualTo "[1]") then {
    diag_log "extDB3: Протокол SQL_CUSTOM (ID=0) успешно загружен.";
} else {
    diag_log format ["extDB3: Ошибка загрузки протокола SQL_CUSTOM (ID=0): %1", _protoResult];
};

private _testSteamID = "76561198000000000";
private _testResult = "extDB3" callExtension format ["0:0:loadPlayer:%1", _testSteamID];
diag_log format ["extDB3: Результат запроса 'loadPlayer' для SteamID %1: %2", _testSteamID, _testResult];

[] spawn {
    while {true} do {
        {
            if (isPlayer _x) then {
                private _uid = getPlayerUID _x;
                private _name = name _x;
                private _pos = getPosATL _x;
                private _xPos = _pos select 0;
                private _yPos = _pos select 1;
                private _zPos = _pos select 2;
                private _inv = getUnitLoadout _x;
                private _invStr = str _inv;

                "extDB3" callExtension format [
                    "0:0:savePlayer:%1:%2:%3:%4:%5:%6",
                    _name, _xPos, _yPos, _zPos, _invStr, _uid
                ];

                diag_log format [
                    "extDB3: [AUTO SAVE] UID: %1 — x: %2 y: %3 z: %4",
                    _uid, _xPos, _yPos, _zPos
                ];
            };
        } forEach allPlayers;
        sleep 10;
    };
};
