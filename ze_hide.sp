#pragma semicolon 1
#pragma newdecls required

#include <multicolors>
#include <clientprefs>
#include <sdkhooks>
#include <zombiereloaded>

enum struct t_settings {
	bool bEnabled;
	int HideDistance;
}

t_settings HideSettings[MAXPLAYERS + 1];
Handle hCookie[2];

public void OnPluginStart() {
	LoadTranslations("hide.phrases.txt");

	hCookie[0] = RegClientCookie("hide_enabled", "", CookieAccess_Private);
	hCookie[1] = RegClientCookie("hide_distance", "", CookieAccess_Private);
	
	RegConsoleCmd("sm_hide", Command);
	
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
	{
		OnClientPutInServer(i);
		OnClientCookiesCached(i);
	}
}

public Action Command(int client, int args) {	
	if(args < 1) {
		HideSettings[client].bEnabled = false;
		SetClientCookie(client, hCookie[0], "0");
		
		return Plugin_Handled;
	}
	
	char sArg[32];
	GetCmdArg(1, sArg, sizeof(sArg));
	
	int units = StringToInt(sArg);

	if(units <= 0) {
		CPrintToChat(client, "%T", "Disabled", client);
		HideSettings[client].bEnabled = false;
		SetClientCookie(client, hCookie[0], "0");
		return Plugin_Handled;
	}
	
	FormatEx(sArg, sizeof(sArg), "%d", units);
	HideSettings[client].HideDistance = units;
	
	SetClientCookie(client, hCookie[0], "1");
	SetClientCookie(client, hCookie[1], sArg);
	
	// Вы включили скрытие зомби [{1} юнитов]
	CPrintToChat(client, "%T", "Enabled", client, units);
	
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client) {
	char sData[32];
	GetClientCookie(client, hCookie[0], sData, sizeof sData);
	
	HideSettings[client].bEnabled = sData[0] == 0 ? false : view_as<bool>(StringToInt(sData));

	GetClientCookie(client, hCookie[1], sData, sizeof sData);
	
	HideSettings[client].HideDistance = sData[0] == 0 ? 0 : StringToInt(sData);
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_SetTransmit, SDKHook_OnTransmit);
}

public Action SDKHook_OnTransmit(int entity, int client) {
	if(entity == client)
		return Plugin_Continue;

	if(GetClientTeam(client) == 1)
		return Plugin_Continue;
	
	if(!HideSettings[client].bEnabled)
		return Plugin_Continue;
		
	if(HideSettings[client].HideDistance == 0)
		return Plugin_Continue;
	
	if(ZR_IsClientHuman(client) && ZR_IsClientZombie(entity)) {
		float fVec[3], fVec2[3];
		GetClientAbsOrigin(client, fVec);
		GetClientAbsOrigin(entity, fVec2);

		if(HideSettings[client].HideDistance >= GetVectorDistance(fVec, fVec2))
			return Plugin_Handled;
	}

	return Plugin_Continue;
}