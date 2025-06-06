class TB_RscText
{
    type = 0;
    idc = -1;
    style = 0;
    colorBackground[] = {0,0,0,0};
    colorText[] = {1,1,1,1};
    font = "PuristaMedium";
    sizeEx = 0.04;
    shadow = 2;
};
class TB_RscButton
{
    type = 1;
    style = 2;
    idc = -1;
    colorText[] = {1,1,1,1};
    colorDisabled[] = {0.4,0.4,0.4,1};
    colorBackground[] = {0.2,0.2,0.2,0.9};
    colorBackgroundDisabled[] = {0.95,0.95,0.95,1};
    colorBackgroundActive[] = {0.3,0.3,0.3,1};
    colorFocused[] = {0.3,0.3,0.3,1};
    colorShadow[] = {0,0,0,1};
    colorBorder[] = {0,0,0,1};
    soundEnter[] = {"\A3\ui_f\data\sound\RscButton\soundEnter",0.09,1};
    soundPush[] = {"\A3\ui_f\data\sound\RscButton\soundPush",0.09,1};
    soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick",0.09,1};
    soundEscape[] = {"\A3\ui_f\data\sound\RscButton\soundEscape",0.09,1};
    font = "PuristaMedium";
    sizeEx = 0.04;
    offsetX = 0.003;
    offsetY = 0.003;
    offsetPressedX = 0.002;
    offsetPressedY = 0.002;
    borderSize = 0;
};
class TB_RscEdit
{
    type = 2;
    idc = -1;
    style = 0;
    font = "PuristaMedium";
    sizeEx = 0.04;
    colorBackground[] = {0,0,0,0.8};
    colorText[] = {1,1,1,1};
    shadow = 2;
};
class TB_InputDialog
{
    idd = -1;
    movingEnable = 0;
    enableSimulation = 1;
    class Controls
    {
        class Background: TB_RscText
        {
            x = 0.4 * safezoneW + safezoneX;
            y = 0.4 * safezoneH + safezoneY;
            w = 0.2 * safezoneW;
            h = 0.15 * safezoneH;
            colorBackground[] = {0,0,0,0.8};
        };
        class Input: TB_RscEdit
        {
            idc = 1;
            x = 0.41 * safezoneW + safezoneX;
            y = 0.45 * safezoneH + safezoneY;
            w = 0.18 * safezoneW;
            h = 0.04 * safezoneH;
        };
        class Ok: TB_RscButton
        {
            idc = 2;
            text = "OK";
            x = 0.46 * safezoneW + safezoneX;
            y = 0.52 * safezoneH + safezoneY;
            w = 0.08 * safezoneW;
            h = 0.04 * safezoneH;
            action = "['ok',_this] call tb_fnc_inputClosed";
        };
    };
};
