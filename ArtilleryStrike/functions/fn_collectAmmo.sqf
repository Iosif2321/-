params["_cond"];
private _cfg=configFile>>"CfgAmmo";
private _arr=[];
{
private _c=_x;
if(getText(_c>>"simulation") in ["shotShell","shotBomb"]&&{_c call _cond})then{_arr pushBack configName _c};
}forEach configProperties[_cfg,"isClass _x"];
_arr
