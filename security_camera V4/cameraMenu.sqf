disableSerialization;

// Инициализация массива камер, если он не определён
if (isNil "camList") then {
    camList = [];

    // Добавляем камеру без индекса
    if (!isNil "cameraObj") then {
        camList pushBack cameraObj;
    };

    // Перебираем cameraObj_1, cameraObj_2, ...
    private _i = 1;
    while {
        private _varName = format ["cameraObj_%1", _i];
        private _cam = missionNamespace getVariable [_varName, objNull];
        !isNull _cam
    } do {
        private _varName = format ["cameraObj_%1", _i];
        private _cam = missionNamespace getVariable [_varName, objNull];
        camList pushBack _cam;
        _i = _i + 1;
    };
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

// Массив индексов камер, отображаемых в мультирежиме
if (isNil "multiCamIndexes") then {
    multiCamIndexes = [];
};

// Массив состояния ПНВ для каждого слота в мультирежиме
if (isNil "nvgEnabledMulti") then {
    nvgEnabledMulti = [];
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
    (_disp displayCtrl 5308) ctrlAddEventHandler ["ButtonClick", {[-1] call switchSelectedMultiCamSlot}];
    (_disp displayCtrl 5309) ctrlAddEventHandler ["ButtonClick", {[1] call switchSelectedMultiCamSlot}];
};

// Применить вращение камеры
applyCameraRotation = {
    params [["_camIndex", currentCamIndex]];

    // Ограничиваем угол наклона
    CAMERA_ROT_X = CAMERA_ROT_X max -89 min 89;
    CAMERA_ROT_Z = CAMERA_ROT_Z % 360;

    // Отладка
    diag_log format ["applyCameraRotation - camIndex: %1, multiCamMode: %2, CAMERA_ROT_X: %3, CAMERA_ROT_Z: %4", _camIndex, multiCamMode, CAMERA_ROT_X, CAMERA_ROT_Z];

    if (multiCamMode) then {
        if (_camIndex >= 0 && _camIndex < count multiCameraBase) then {
            private _base = multiCameraBase select _camIndex;
            if (!isNull _base) then {
                _base setVectorDirAndUp [
                    [cos CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_X],
                    [0, 0, 1]
                ];
            } else {
                diag_log format ["applyCameraRotation ERROR: multiCameraBase at index %1 is null", _camIndex];
            };
        } else {
            diag_log format ["applyCameraRotation ERROR: Invalid _camIndex %1 for multiCameraBase (count: %2)", _camIndex, count multiCameraBase];
        };
    } else {
        if (!isNull cameraBase) then {
            cameraBase setVectorDirAndUp [
                [cos CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_X],
                [0, 0, 1]
            ];
        } else {
            diag_log "applyCameraRotation ERROR: cameraBase is null";
        };
    };
};

// Переключение выбранной камеры в мультирежиме на другую
switchSelectedMultiCam = {
    params ["_dir"];
    if (count camList == 0) exitWith {};

    if (multiCamMode) then {
        // Получаем индекс камеры, которая сейчас отображается в выбранном слоте
        private _currentSlotCamIndex = multiCamIndexes select selectedMultiCamIndex;
        
        // Вычисляем новый индекс камеры для этого слота
        private _newCamIndex = (_currentSlotCamIndex + _dir + count camList) mod count camList;
        
        // Обновляем индекс в массиве
        multiCamIndexes set [selectedMultiCamIndex, _newCamIndex];
        
        // Обновляем саму камеру в этом слоте
        [selectedMultiCamIndex] call updateMultiCamSlot;
        
        // Обновляем отображение информации о выбранной камеры
        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            private _slotTextCtrl = _disp displayCtrl (5600 + selectedMultiCamIndex);
            if (!isNull _slotTextCtrl) then {
                _slotTextCtrl ctrlSetText format ["Камера %1", _newCamIndex + 1];
            };
            
            (_disp displayCtrl 5198) ctrlSetText format ["Мульти-режим - Слот %1 - Камера %2", 
                selectedMultiCamIndex + 1, _newCamIndex + 1];
        };
        
        // Обновляем данные о повороте для выбранной камеры
        private _rot = camRotationData select _newCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
    };
};

// Переключение выбранного слота в мультирежиме
switchSelectedMultiCamSlot = {
    params ["_dir"];
    if (!multiCamMode) exitWith {};

    private _newSlotIndex = (selectedMultiCamIndex + _dir + multiCamCount) mod multiCamCount;
    selectedMultiCamIndex = _newSlotIndex;

    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        // Обновляем рамки для выделения активного слота
        {
            private _borderCtrl = _disp displayCtrl (5500 + _forEachIndex);
            if (!isNull _borderCtrl) then {
                if (_forEachIndex == selectedMultiCamIndex) then {
                    _borderCtrl ctrlSetTextColor [1, 0, 0, 1];
                    _borderCtrl ctrlSetBackgroundColor [1, 0, 0, 0.3];
                } else {
                    _borderCtrl ctrlSetTextColor [1, 1, 1, 0];
                    _borderCtrl ctrlSetBackgroundColor [0, 0, 0, 0];
                };
                _borderCtrl ctrlCommit 0;
            };
        } forEach activeMultiCams;

        // Обновляем заголовок и состояние ПНВ
        private _camIndex = multiCamIndexes select selectedMultiCamIndex;
        (_disp displayCtrl 5198) ctrlSetText format ["Мульти-режим - Слот %1 - Камера %2", 
            selectedMultiCamIndex + 1, _camIndex + 1];
        private _nvgText = if (nvgEnabledMulti select selectedMultiCamIndex) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"};
        (_disp displayCtrl 5203) ctrlSetText _nvgText;

        // Обновляем данные о повороте для выбранной камеры
        private _rot = camRotationData select _camIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
    };
};

// Обновить камеру в выбранном слоте мультирежима
updateMultiCamSlot = {
    params ["_slotIndex"];

    if (_slotIndex < 0 || _slotIndex >= count activeMultiCams) exitWith {};

    // Получаем индекс камеры для этого слота
    private _camIndex = multiCamIndexes select _slotIndex;
    private _obj = camList select _camIndex;

    // Обновляем позицию базы камеры
    if (_slotIndex < count multiCameraBase) then {
        private _base = multiCameraBase select _slotIndex;
        if (!isNull _base) then {
            _base setPosASL getPosASL _obj;
            
            // Применяем сохраненный поворот
            private _rot = camRotationData select _camIndex;
            _base setVectorDirAndUp [
                [cos (_rot select 0) * cos (_rot select 1), sin (_rot select 0) * cos (_rot select 1), sin (_rot select 1)],
                [0, 0, 1]
            ];
        };
    };

    // Обновляем камеру
    if (_slotIndex < count activeMultiCams) then {
        private _cam = activeMultiCams select _slotIndex;
        if (!isNull _cam) then {
            _cam cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _slotIndex]];
            camDestroy _cam;
        };
        
        private _newCam = "camera" camCreate getPosATL _obj;
        _newCam camSetFov 0.8;
        _newCam camCommit 0;
        _newCam attachTo [multiCameraBase select _slotIndex, [0,0,0]];
        _newCam cameraEffect ["Internal", "Back", format ["MultiCamFeed_%1", _slotIndex]];
        format ["MultiCamFeed_%1", _slotIndex] setPiPEffect [if (nvgEnabledMulti select _slotIndex) then {1} else {0}];
        activeMultiCams set [_slotIndex, _newCam];
    };
};

// Переключение между камерами
switchCam = {
    params ["_dir"];
    if (count camList == 0) exitWith {};

    if (multiCamMode) then {
        [_dir] call switchSelectedMultiCam;
    } else {
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
    if (multiCamMode) then {
        private _slotIndex = selectedMultiCamIndex;
        private _enabled = !(nvgEnabledMulti select _slotIndex);
        nvgEnabledMulti set [_slotIndex, _enabled];
        private _feedName = format ["MultiCamFeed_%1", _slotIndex];
        _feedName setPiPEffect [if (_enabled) then {1} else {0}];
    } else {
        nvgEnabled = !nvgEnabled;
        "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];
    };
    
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5203) ctrlSetText (if (multiCamMode) then {
            if (nvgEnabledMulti select selectedMultiCamIndex) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"}
        } else {
            if (nvgEnabled) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"}
        });
    };
};

// Отключение от камеры
disconnectCam = {
    if (multiCamMode) then {
        {
            if (!isNull _x) then {
                _x cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _forEachIndex]];
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
        multiCamIndexes = [];
        nvgEnabledMulti = [];
    } else {
        if (!isNull activeCam) then {
            activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
            camDestroy activeCam;
        };
        if (!isNull cameraBase) then { deleteVehicle cameraBase; };
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
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
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
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
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
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
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
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
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
                _x cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _forEachIndex]];
                camDestroy _x;
            };
        } forEach activeMultiCams;
        
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach multiCameraBase;
        
        // Полная очистка массивов перед переключением
        activeMultiCams = [];
        multiCameraBase = [];
        multiCamIndexes = [];
        nvgEnabledMulti = [];
        
        // Логирование для отладки
        diag_log format ["Switching to single mode - activeMultiCams: %1, multiCameraBase: %2", activeMultiCams, multiCameraBase];
        
        multiCamMode = false;

        // Проверяем, что currentCamIndex валиден
        if (currentCamIndex < 0 || currentCamIndex >= count camList) then {
            currentCamIndex = 0 max ((count camList - 1) min currentCamIndex);
            diag_log format ["toggleMultiCamMode: Adjusted currentCamIndex to %1", currentCamIndex];
        };

        // Открываем одиночную камеру
        private _obj = camList select currentCamIndex;
        if (isNull _obj) exitWith {
            diag_log "toggleMultiCamMode ERROR: Camera object is null";
            hint "Ошибка: Камера недоступна";
        };
        
        if (isNull cameraBase) then {
            cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
            cameraBase hideObject true;
        };
        cameraBase setPosASL getPosASL _obj;
        
        // Проверяем, что camRotationData имеет данные для currentCamIndex
        if (currentCamIndex >= count camRotationData) then {
            for "_i" from (count camRotationData) to currentCamIndex do {
                camRotationData pushBack [0, 0];
            };
        };

        private _rot = camRotationData select currentCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
        
        if (isNull activeCam) then {
            activeCam = "camera" camCreate getPosATL _obj;
            activeCam camSetFov 0.8;
            activeCam camCommit 0;
            activeCam attachTo [cameraBase, [0,0,0]];
            activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
            "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];
        } else {
            activeCam camSetPos getPosATL _obj;
            activeCam camCommit 0;
        };
        
        [currentCamIndex] call applyCameraRotation;
        
        selectedMultiCamIndex = 0;
        
        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            (_disp displayCtrl 5198) ctrlSetText format ["Камера %1", currentCamIndex + 1];
            (_disp displayCtrl 5203) ctrlSetText (if (nvgEnabled) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"});
            (_disp displayCtrl 5306) ctrlSetText "МУЛЬТИ-РЕЖИМ";
            (_disp displayCtrl 5307) ctrlShow false;
            (_disp displayCtrl 5308) ctrlShow false;
            (_disp displayCtrl 5309) ctrlShow false;

            // Скрыть мульти-камерные контролы
            for "_i" from 0 to 7 do {
                private _ctrl = _disp displayCtrl (5400 + _i);
                if (!isNull _ctrl) then { _ctrl ctrlShow false; };
                private _borderCtrl = _disp displayCtrl (5500 + _i);
                if (!isNull _borderCtrl) then { _borderCtrl ctrlShow false; };
                private _textCtrl = _disp displayCtrl (5600 + _i);
                if (!isNull _textCtrl) then { _textCtrl ctrlShow false; };
            };
            (_disp displayCtrl 5200) ctrlShow true;
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
            (_disp displayCtrl 5198) ctrlSetText format ["Мульти-режим - Слот %1 - Камера %2", 
                selectedMultiCamIndex + 1, (multiCamIndexes select selectedMultiCamIndex) + 1];
            (_disp displayCtrl 5203) ctrlSetText (if (nvgEnabledMulti select selectedMultiCamIndex) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"});
            (_disp displayCtrl 5306) ctrlSetText "ОДИНОЧНЫЙ РЕЖИМ";
            (_disp displayCtrl 5307) ctrlShow true;
            (_disp displayCtrl 5308) ctrlShow true;
            (_disp displayCtrl 5309) ctrlShow true;
            (_disp displayCtrl 5307) ctrlSetText format ["КАМЕР: %1", multiCamCount];
        };
    };
};

// Настройка мульти-камерного режима
setupMultiCamMode = {
    // Очистить предыдущие камеры, если есть
    {
        if (!isNull _x) then {
            _x cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _forEachIndex]];
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
    multiCamIndexes = [];
    nvgEnabledMulti = [];
    
    // Инициализация multiCamIndexes
    for "_i" from 0 to (multiCamCount - 1) do {
        private _camIndex = (currentCamIndex + _i) mod count camList;
        multiCamIndexes pushBack _camIndex;
        nvgEnabledMulti pushBack false;
    };
    
    // Создаем новые камеры
    for "_i" from 0 to (multiCamCount - 1) do {
        private _camIndex = multiCamIndexes select _i;
        private _obj = camList select _camIndex;
        
        // Предварительная инициализация рендер-таргета
        format ["MultiCamFeed_%1", _i] setPiPEffect [0];
        
        private _base = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
        _base hideObject true;
        _base setPosASL getPosASL _obj;
        multiCameraBase pushBack _base;
        
        private _cam = "camera" camCreate getPosATL _obj;
        _cam camSetFov 0.8;
        _cam camCommit 0;
        _cam attachTo [_base, [0,0,0]];
        _cam cameraEffect ["Internal", "Back", format ["MultiCamFeed_%1", _i]];
        format ["MultiCamFeed_%1", _i] setPiPEffect [if (nvgEnabledMulti select _i) then {1} else {0}];
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
        
        // Удаляем старый обработчик событий, если он существует
        if (!isNull _ctrl) then {
            _ctrl ctrlRemoveAllEventHandlers "MouseButtonDown";
        } else {
            _ctrl = _disp ctrlCreate ["RscPicture", _ctrlId];
        };
        
        _ctrl ctrlSetText format ["#(argb,512,512,1)r2t(MultiCamFeed_%1,1.333)", _i];
        _ctrl ctrlSetPosition [_x, _y, _camW, _camH];
        _ctrl ctrlShow true;
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
        _borderCtrl ctrlShow true;
        _borderCtrl ctrlCommit 0;
        
        // Добавляем текст с номером камеры
        private _textCtrlId = 5600 + _i;
        private _textCtrl = _disp displayCtrl _textCtrlId;
        
        if (isNull _textCtrl) then {
            _textCtrl = _disp ctrlCreate ["RscText", _textCtrlId];
        };
        
        private _camIndex = multiCamIndexes select _i;
        _textCtrl ctrlSetText format ["Камера %1", _camIndex + 1];
        _textCtrl ctrlSetPosition [_x + (_camW * 0.05), _y + (_camH * 0.8), _camW * 0.9, _camH * 0.15];
        _textCtrl ctrlSetTextColor [1, 1, 1, 1];
        _textCtrl ctrlShow true;
        _textCtrl ctrlCommit 0;
    };
    
    // Скрыть неиспользуемые контролы
    for "_i" from _numCams to 7 do {
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