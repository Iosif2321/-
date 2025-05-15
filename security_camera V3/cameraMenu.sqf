disableSerialization;

// Инициализация массива камер, если он не определён
if (isNil "camList") then {
    camList = [cameraObj1, cameraObj2, cameraObj3];
};

// Инициализация данных о повороте камер
if (isNil "camRotationData") then {
    camRotationData = [];
    {
        camRotationData pushBack [0, 0];
    } forEach camList;
};

// Инициализация переменных для мультикамерного режима
if (isNil "multiCamMode") then {
    multiCamMode = false;
};

if (isNil "multiCamCount") then {
    multiCamCount = 4; // По умолчанию 4 камеры в мульти-режиме
};

// Инициализация массивов активных камер и базовых объектов
if (isNil "activeMultiCams") then {
    activeMultiCams = [];
};

if (isNil "multiCameraBase") then {
    multiCameraBase = [];
};

// Глобальные переменные
activeCam = objNull;
cameraBase = objNull;
currentCamIndex = -1;
nvgEnabled = false;
tfar_relay_agent = objNull;

// Константы для вращения камеры
CAMERA_ROT_STEP = 30;
CAMERA_ROT_FIXED = false;
CAMERA_ROT_X = 0;
CAMERA_ROT_Z = 0;

// Выбранная камера в мультирежиме (для управления)
selectedMultiCamIndex = 0;

// Закрыть меню камеры
closeCamMenu = { closeDialog 0 };

// Открыть просмотр выбранной камеры
openCamView = {
    private _menuDisp = findDisplay 5000;
    if (isNull _menuDisp) exitWith {};
    private _listCtrl = _menuDisp displayCtrl 5100;
    private _selIndex = lbCurSel _listCtrl;
    if (_selIndex < 0) exitWith { hint "Выберите камеру"; };

    currentCamIndex = _selIndex;
    closeDialog 0;
    createDialog "CameraViewDialog";

    private _disp = findDisplay 5001;
    (_disp displayCtrl 5198) ctrlSetText format ["Камера %1", currentCamIndex + 1];
    (_disp displayCtrl 5203) ctrlSetText "ВКЛЮЧИТЬ ПНВ";
    (_disp displayCtrl 5304) ctrlSetText format ["ШАГ: %1°", CAMERA_ROT_STEP];
    (_disp displayCtrl 5305) ctrlSetText "ФИКСАЦИЯ";
    (_disp displayCtrl 5306) ctrlSetText "МУЛЬТИ-РЕЖИМ";
    nvgEnabled = false;
    multiCamMode = false;

    private _obj = camList select currentCamIndex;
    if (!isNull activeCam) then {
        activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
        camDestroy activeCam;
    };
    if (!isNull cameraBase) then { deleteVehicle cameraBase; };

    cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
    cameraBase hideObject true;
    cameraBase setPosASL getPosASL _obj;
    CAMERA_ROT_X = 0;
    CAMERA_ROT_Z = 0;

    private _rot = camRotationData select currentCamIndex;
    CAMERA_ROT_Z = _rot select 0;
    CAMERA_ROT_X = _rot select 1;

    activeCam = "camera" camCreate getPosATL _obj;
    activeCam camSetFov 0.8;
    activeCam camCommit 0;
    activeCam attachTo [cameraBase, [0,0,0]];
    activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
    "CameraFeed" setPiPEffect [0];

    if (isNil "tfar_relay_agent") then {
        tfar_relay_agent = "VirtualMan_F" createVehicleLocal [0,0,0];
        tfar_relay_agent setVariable ["TFAR_forceSpectator", true, true];
    };
    tfar_relay_agent setPosASL getPosASL activeCam;
    player setVariable ["TFAR_spectatorEntity", tfar_relay_agent, true];

    // Добавление обработчиков событий
    (_disp displayCtrl 5201) ctrlAddEventHandler ["ButtonClick", {[-1] call switchCam}];
    (_disp displayCtrl 5202) ctrlAddEventHandler ["ButtonClick", {[1] call switchCam}];
    (_disp displayCtrl 5203) ctrlAddEventHandler ["ButtonClick", {call toggleNV}];
    (_disp displayCtrl 5204) ctrlAddEventHandler ["ButtonClick", {call disconnectCam}];
    (_disp displayCtrl 5300) ctrlAddEventHandler ["ButtonClick", {call rotateCamLeft}];
    (_disp displayCtrl 5301) ctrlAddEventHandler ["ButtonClick", {call rotateCamRight}];
    (_disp displayCtrl 5302) ctrlAddEventHandler ["ButtonClick", {call rotateCamUp}];
    (_disp displayCtrl 5303) ctrlAddEventHandler ["ButtonClick", {call rotateCamDown}];
    (_disp displayCtrl 5304) ctrlAddEventHandler ["ButtonClick", {call toggleStep}];
    (_disp displayCtrl 5305) ctrlAddEventHandler ["ButtonClick", {call toggleFix}];
    (_disp displayCtrl 5306) ctrlAddEventHandler ["ButtonClick", {call toggleMultiCamMode}];
    (_disp displayCtrl 5307) ctrlAddEventHandler ["ButtonClick", {call cycleMultiCamCount}];
};

// Применить вращение камеры
applyCameraRotation = {
    params [["_camIndex", currentCamIndex]];
    
    CAMERA_ROT_X = CAMERA_ROT_X max -89 min 89;
    
    if (multiCamMode) then {
        if (_camIndex >= 0 && _camIndex < count multiCameraBase && {!isNull (multiCameraBase select _camIndex)}) then {
            (multiCameraBase select _camIndex) setVectorDirAndUp [
                [cos CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_X],
                [0, 0, 1]
            ];
        };
    } else {
        if (!isNull cameraBase) then {
            cameraBase setVectorDirAndUp [
                [cos CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_X],
                [0, 0, 1]
            ];
        };
    };
};

// Переключение между камерами
switchCam = {
    params ["_dir"];
    if (count camList == 0) exitWith {};
    
    if (multiCamMode) then {
        // В мультирежиме меняем выбранную камеру для управления
        selectedMultiCamIndex = (selectedMultiCamIndex + _dir + multiCamCount) mod multiCamCount;
        
        private _actualCamIndex = (currentCamIndex + selectedMultiCamIndex) mod count camList;
        private _rot = camRotationData select _actualCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
        
        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            (_disp displayCtrl 5198) ctrlSetText format ["Мульти-режим - Выбрана камера %1", selectedMultiCamIndex + 1];
        };
    } else {
        // В обычном режиме переключаем камеру
        if (!isNull activeCam) then {
            activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
            camDestroy activeCam;
        };
        if (!isNull cameraBase) then { deleteVehicle cameraBase; };

        currentCamIndex = (currentCamIndex + _dir + count camList) mod count camList;
        private _obj = camList select currentCamIndex;

        cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
        cameraBase hideObject true;
        cameraBase setPosASL getPosASL _obj;
        
        private _rot = camRotationData select currentCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;

        activeCam = "camera" camCreate getPosATL _obj;
        activeCam camSetFov 0.8;
        activeCam camCommit 0;
        activeCam attachTo [cameraBase, [0,0,0]];
        activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
        "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];

        if (!isNull tfar_relay_agent) then {
            tfar_relay_agent setPosASL getPosASL activeCam;
        };

        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            (_disp displayCtrl 5198) ctrlSetText format ["Камера %1", currentCamIndex + 1];
            (_disp displayCtrl 5203) ctrlSetText (if (nvgEnabled) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"});
        };
        
        [currentCamIndex] call applyCameraRotation;
    };
};

// Переключение ПНВ для камеры
toggleNV = {
    nvgEnabled = !nvgEnabled;
    
    if (multiCamMode) then {
        {
            private _feedName = format ["CameraFeed_%1", _forEachIndex];
            _feedName setPiPEffect [if (nvgEnabled) then {1} else {0}];
        } forEach activeMultiCams;
    } else {
        "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];
    };
    
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5203) ctrlSetText (if (nvgEnabled) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"});
    };
};

// Отключение от камеры
disconnectCam = {
    if (multiCamMode) then {
        {
            if (!isNull _x) then {
                _x cameraEffect ["Terminate", "Back", format ["CameraFeed_%1", _forEachIndex]];
                camDestroy _x;
            };
        } forEach activeMultiCams;
        
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach multiCameraBase;
        
        activeMultiCams = [];
        multiCameraBase = [];
    } else {
        if (!isNull activeCam) then {
            activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
            camDestroy activeCam;
        };
        if (!isNull cameraBase) then {
            deleteVehicle cameraBase;
        };
    };
    
    player setVariable ["TFAR_spectatorEntity", objNull, true];
    closeDialog 0;
};

// Функции поворота камеры
rotateCamLeft = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_Z = (CAMERA_ROT_Z + CAMERA_ROT_STEP) % 360;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = (currentCamIndex + selectedMultiCamIndex) mod count camList;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

rotateCamRight = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_Z = (CAMERA_ROT_Z - CAMERA_ROT_STEP + 360) % 360;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = (currentCamIndex + selectedMultiCamIndex) mod count camList;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

rotateCamUp = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_X = CAMERA_ROT_X + CAMERA_ROT_STEP;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = (currentCamIndex + selectedMultiCamIndex) mod count camList;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

rotateCamDown = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_X = CAMERA_ROT_X - CAMERA_ROT_STEP;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = (currentCamIndex + selectedMultiCamIndex) mod count camList;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

// Переключить шаг поворота камеры
toggleStep = {
    switch (CAMERA_ROT_STEP) do {
        case 5:  { CAMERA_ROT_STEP = 15; };
        case 15: { CAMERA_ROT_STEP = 30; };
        case 30: { CAMERA_ROT_STEP = 5; };
    };
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5304) ctrlSetText format ["ШАГ: %1°", CAMERA_ROT_STEP];
    };
};

// Переключить фиксацию камеры
toggleFix = {
    CAMERA_ROT_FIXED = !CAMERA_ROT_FIXED;
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5305) ctrlSetText (if (CAMERA_ROT_FIXED) then {"РАЗБЛОКА"} else {"ФИКСАЦИЯ"});
    };
};

// Переключение между одно- и многокамерным режимом
toggleMultiCamMode = {
    if (multiCamMode) then {
        // Переключаемся с мульти-режима на одиночный
        {
            if (!isNull _x) then {
                _x cameraEffect ["Terminate", "Back", format ["CameraFeed_%1", _forEachIndex]];
                camDestroy _x;
            };
        } forEach activeMultiCams;
        
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach multiCameraBase;
        
        activeMultiCams = [];
        multiCameraBase = [];
        
        // Открываем одиночную камеру
        private _obj = camList select currentCamIndex;
        
        cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
        cameraBase hideObject true;
        cameraBase setPosASL getPosASL _obj;
        
        private _rot = camRotationData select currentCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
        
        activeCam = "camera" camCreate getPosATL _obj;
        activeCam camSetFov 0.8;
        activeCam camCommit 0;
        activeCam attachTo [cameraBase, [0,0,0]];
        activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
        "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];
        
        call applyCameraRotation;
        
        multiCamMode = false;
        selectedMultiCamIndex = 0;
        
        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            (_disp displayCtrl 5198) ctrlSetText format ["Камера %1", currentCamIndex + 1];
            (_disp displayCtrl 5306) ctrlSetText "МУЛЬТИ-РЕЖИМ";
            (_disp displayCtrl 5307) ctrlShow false;
        };
    } else {
        // Переключаемся с одиночного на мульти-режим
        if (!isNull activeCam) then {
            activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
            camDestroy activeCam;
        };
        if (!isNull cameraBase) then {
            deleteVehicle cameraBase;
        };
        
        activeCam = objNull;
        cameraBase = objNull;
        
        // Создаем мульти-камеры
        call setupMultiCamMode;
        
        multiCamMode = true;
        selectedMultiCamIndex = 0;
        
        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            (_disp displayCtrl 5198) ctrlSetText format ["Мульти-режим - Выбрана камера %1", selectedMultiCamIndex + 1];
            (_disp displayCtrl 5306) ctrlSetText "ОДИНОЧНЫЙ РЕЖИМ";
            (_disp displayCtrl 5307) ctrlShow true;
            (_disp displayCtrl 5307) ctrlSetText format ["КАМЕР: %1", multiCamCount];
        };
    };
};

// Настройка мульти-камерного режима
setupMultiCamMode = {
    // Очистить предыдущие камеры, если есть
    {
        if (!isNull _x) then {
            _x cameraEffect ["Terminate", "Back", format ["CameraFeed_%1", _forEachIndex]];
            camDestroy _x;
        };
    } forEach activeMultiCams;
    
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach multiCameraBase;
    
    activeMultiCams = [];
    multiCameraBase = [];
    
    // Создаем новые камеры
    for "_i" from 0 to (multiCamCount - 1) do {
        private _camIndex = (currentCamIndex + _i) mod count camList;
        private _obj = camList select _camIndex;
        
        private _base = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
        _base hideObject true;
        _base setPosASL getPosASL _obj;
        multiCameraBase pushBack _base;
        
        private _cam = "camera" camCreate getPosATL _obj;
        _cam camSetFov 0.8;
        _cam camCommit 0;
        _cam attachTo [_base, [0,0,0]];
        _cam cameraEffect ["Internal", "Back", format ["CameraFeed_%1", _i]];
        format ["CameraFeed_%1", _i] setPiPEffect [if (nvgEnabled) then {1} else {0}];
        activeMultiCams pushBack _cam;
        
        private _rot = camRotationData select _camIndex;
        if (_i == selectedMultiCamIndex) then {
            CAMERA_ROT_Z = _rot select 0;
            CAMERA_ROT_X = _rot select 1;
        };
        
        _base setVectorDirAndUp [
            [cos (_rot select 0) * cos (_rot select 1), sin (_rot select 0) * cos (_rot select 1), sin (_rot select 1)],
            [0, 0, 1]
        ];
    };
    
    // Обновляем интерфейс для отображения мульти-камер
    [multiCamCount] call updateMultiCamDisplay;
};

// Обновить отображение мульти-камер
updateMultiCamDisplay = {
    params ["_numCams"];
    
    private _disp = findDisplay 5001;
    if (isNull _disp) exitWith {};
    
    // Скрыть основной экран камеры
    (_disp displayCtrl 5200) ctrlShow false;
    
    // Получить базовые размеры области просмотра
    private _baseX = 0.26 * safezoneW + safezoneX;
    private _baseY = 0.25 * safezoneH + safezoneY;
    private _baseW = 0.48 * safezoneW;
    private _baseH = 0.36 * safezoneH;
    
    // Расчет размеров и позиций камер
    private _cols = switch (_numCams) do {
        case 4: { 2 };
        case 6: { 3 };
        case 8: { 4 };
        default { 2 };
    };
    
    private _rows = ceil (_numCams / _cols);
    private _camW = _baseW / _cols;
    private _camH = _baseH / _rows;
    
    // Создать или обновить элементы управления для каждой камеры
    for "_i" from 0 to (_numCams - 1) do {
        private _col = _i mod _cols;
        private _row = floor (_i / _cols);
        
        private _x = _baseX + (_col * _camW);
        private _y = _baseY + (_row * _camH);
        
        private _ctrlId = 5400 + _i;
        private _ctrl = _disp displayCtrl _ctrlId;
        
        // Если контрол не существует, создаем его
        if (isNull _ctrl) then {
            _ctrl = _disp ctrlCreate ["RscPicture", _ctrlId];
            _ctrl ctrlAddEventHandler ["MouseButtonDown", format ["selectedMultiCamIndex = %1; private _actualCamIndex = (currentCamIndex + selectedMultiCamIndex) mod count camList; private _rot = camRotationData select _actualCamIndex; CAMERA_ROT_Z = _rot select 0; CAMERA_ROT_X = _rot select 1; private _disp = findDisplay 5001; if (!isNull _disp) then { (_disp displayCtrl 5198) ctrlSetText format ['Мульти-режим - Выбрана камера %2', selectedMultiCamIndex + 1]; };", _i, _i + 1]];
        };
        
        _ctrl ctrlSetText format ["#(argb,512,512,1)r2t(CameraFeed_%1,1.333)", _i];
        _ctrl ctrlSetPosition [_x, _y, _camW, _camH];
        _ctrl ctrlCommit 0;
        
        // Добавляем индикатор выбранной камеры
        private _borderCtrlId = 5500 + _i;
        private _borderCtrl = _disp displayCtrl _borderCtrlId;
        
        if (isNull _borderCtrl) then {
            _borderCtrl = _disp ctrlCreate ["RscText", _borderCtrlId];
        };
        
        _borderCtrl ctrlSetPosition [_x, _y, _camW, _camH];
        if (_i == selectedMultiCamIndex) then {
            _borderCtrl ctrlSetTextColor [1, 0, 0, 1];
            _borderCtrl ctrlSetBackgroundColor [1, 0, 0, 0.3];
        } else {
            _borderCtrl ctrlSetTextColor [1, 1, 1, 0];
            _borderCtrl ctrlSetBackgroundColor [0, 0, 0, 0];
        };
        _borderCtrl ctrlCommit 0;
        
        // Добавляем текст с номером камеры
        private _textCtrlId = 5600 + _i;
        private _textCtrl = _disp displayCtrl _textCtrlId;
        
        if (isNull _textCtrl) then {
            _textCtrl = _disp ctrlCreate ["RscText", _textCtrlId];
        };
        
        private _actualCamIndex = (currentCamIndex + _i) mod count camList;
        _textCtrl ctrlSetText format ["Камера %1", _actualCamIndex + 1];
        _textCtrl ctrlSetPosition [_x, _y, _camW, 0.03 * safezoneH];
        _textCtrl ctrlSetBackgroundColor [0, 0, 0, 0.7];
        _textCtrl ctrlCommit 0;
    };
    
    // Скрыть неиспользуемые контролы
    for "_i" from _numCams to 8 do {
        private _ctrlId = 5400 + _i;
        private _ctrl = _disp displayCtrl _ctrlId;
        if (!isNull _ctrl) then {
            _ctrl ctrlShow false;
        };
        
        private _borderCtrlId = 5500 + _i;
        private _borderCtrl = _disp displayCtrl _borderCtrlId;
        if (!isNull _borderCtrl) then {
            _borderCtrl ctrlShow false;
        };
        
        private _textCtrlId = 5600 + _i;
        private _textCtrl = _disp displayCtrl _textCtrlId;
        if (!isNull _textCtrl) then {
            _textCtrl ctrlShow false;
        };
    };
};

// Циклическое переключение количества камер в мульти-режиме
cycleMultiCamCount = {
    if (!multiCamMode) exitWith {};
    
    switch (multiCamCount) do {
        case 4: { multiCamCount = 6; };
        case 6: { multiCamCount = 8; };
        case 8: { multiCamCount = 4; };
        default { multiCamCount = 4; };
    };
    
    call setupMultiCamMode;
    
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5307) ctrlSetText format ["КАМЕР: %1", multiCamCount];
    };
};

// Добавление действия к терминалу
if (!isNil "terminalObj" && {!isNull terminalObj}) then {
    terminalObj addAction ["Открыть камеры наблюдения", {
        createDialog "CameraMenuDialog";
        private _menuDisp = findDisplay 5000;
        private _listCtrl = _menuDisp displayCtrl 5100;
        lbClear _listCtrl;
        {
            _listCtrl lbAdd format ["Камера %1", _forEachIndex + 1];
        } forEach camList;
    }];
};

// Проверка массива данных поворота камер и добавление новых данных при необходимости
if (count camRotationData < count camList) then {
    for "_i" from (count camRotationData) to ((count camList) - 1) do {
        camRotationData pushBack [0, 0];
    };
};