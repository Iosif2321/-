params ["_player"];

private _uid = getPlayerUID _player;
private _name = name _player;
private _pos = getPosATL _player;
private _x = _pos select 0;
private _y = _pos select 1;
private _z = _pos select 2;

// Загрузка данных игрока
private _raw = "extDB3" callExtension format ["0:0:loadPlayer:%1", _uid];
diag_log format ["extDB3: Сырые данные игрока: %1", _raw];

private _result = if (_raw isEqualType "") then {
    if (_raw select [0,1] == "[") then {
        call compile _raw
    } else {
        [0, []]
    }
} else {
    [0, []]
};

diag_log format ["extDB3: данные игрока: %1", _result];

if ((_result select 0) isEqualTo 1 && {count (_result select 1) > 0}) then {
    private _data = (_result select 1) select 0;
    private _invStr = _data select 5;
    if (_invStr != "") then {
        private _loadout = call compile _invStr;
        _player setUnitLoadout _loadout;
        diag_log format ["extDB3: Инвентарь игрока %1 восстановлен", _uid];
    };
    diag_log format ["extDB3: Загруженные координаты: %1, %2, %3", _data select 2, _data select 3, _data select 4];
} else {
    private _invStr = str (getUnitLoadout _player);
    "extDB3" callExtension format ["0:0:newPlayer:%1:%2:%3:%4:%5:%6", _uid, _name, _x, _y, _z, _invStr];
    diag_log format ["extDB3: Новый игрок создан: %1", _uid];
};
