#pragma semicolon 1
#pragma newdecls required

#include <multicolors>
#include <clientprefs>
#include <sdkhooks>

Handle hCookie[2];
ConVar hCvar;

bool
	bZM,
	bHide[MAXPLAYERS + 1],
	bSelect[MAXPLAYERS + 1];

int iHideUnits[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "Hide",
	author = "who",
	description = "Plugin for hide players",
	version = "1.0",
};

public void OnPluginStart() {
	RegConsoleCmd("sm_hide", Command);
	RegConsoleCmd("hide", Command);

	AddCommandListener(OnSay, "say");
	AddCommandListener(OnSay, "say_team");

	LoadTranslations("hide.phrases");
	
	hCvar = CreateConVar("hide_mode_zm", "0");
	hCvar.AddChangeHook(OnCvarChanged);
	bZM = hCvar.BoolValue;

	hCookie[0] = RegClientCookie("hide_enabled", "", CookieAccess_Private);
	hCookie[1] = RegClientCookie("hide_units", "", CookieAccess_Private);

	SetCookieMenuItem(CookieHandler, 0, "");

	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i))
			OnClientCookiesCached(i);
}

public void OnCvarChanged(ConVar cvar, const char[] oldVal, const char[] newVal) {
	bZM = view_as<bool>(StringToInt(newVal));
}

public Action Command(int client, int args) {
	if(!client)
		return Plugin_Handled;
	
	ShowMenu(client);
	
	return Plugin_Handled;
}

public void OnClientPutInServer(int client) {
	bSelect[client] = false;

	SDKHook(client, SDKHook_SetTransmit, OnSetTransmit);
}

public void OnClientCookiesCached(int client) {
	char szValue[8];
	GetClientCookie(client, hCookie[0], szValue, sizeof(szValue));
	
	if(szValue[0])
		bHide[client] = view_as<bool>(StringToInt(szValue)); // char to bool
	else bHide[client] = false;
	
	GetClientCookie(client, hCookie[1], szValue, sizeof(szValue));
	
	if(szValue[0])
		iHideUnits[client] = StringToInt(szValue); // char to bool
	else iHideUnits[client] = 128;
}

public Action OnSetTransmit(int entity, int client) {
	if(entity == client)
		return Plugin_Continue;

	if(!bHide[client])
		return Plugin_Continue;
	
	if(bZM && GetClientTeam(entity) & GetClientTeam(client) != 3)
		return Plugin_Continue;

	float vec[2][3];
	int iActiveWeapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");

	if(IsValidEdict(iActiveWeapon))
		SDKHook(iActiveWeapon, SDKHook_SetTransmit, OnSetTransmit_Weapon);

	GetClientAbsOrigin(entity, vec[0]);
	GetClientAbsOrigin(client, vec[1]);

	if(iHideUnits[client] > GetVectorDistance(vec[0], vec[1]))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action OnSetTransmit_Weapon(int entity, int client) {
	if(bHide[client])
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public Action OnSay(int client, const char[] command, int argc) {
	if(!bSelect[client])
		return Plugin_Continue;

	char message[8];
	GetCmdArgString(message, sizeof(message));

	StripQuotes(message);

	int iUnits = StringToInt(message);
	
	if(iUnits <= 0) {
		SetGlobalTransTarget(client);
		CPrintToChat(client, "%t %t", "Prefix", "ErrorRadius");
		
		bSelect[client] = false;
		
		ShowMenu(client);

		return Plugin_Handled;
	}
	
	iHideUnits[client] = iUnits;
	bSelect[client] = false;

	SetGlobalTransTarget(client);
	CPrintToChat(client, "%t %t", "Prefix", "SetRadius", iHideUnits[client]);
	ShowMenu(client);

	return Plugin_Handled;
}

void ShowMenu(int client) {
	Menu menu = new Menu(Menu_Handler);
	
	char sItemTitle[72];
	FormatEx(sItemTitle, sizeof(sItemTitle), "%T\n ", "MenuTitle", client);
	menu.SetTitle(sItemTitle);

	FormatEx(sItemTitle, sizeof(sItemTitle), "%T", "MenuEnabled", client);
	Format(sItemTitle, sizeof(sItemTitle), "%s [%s]", sItemTitle, bHide[client] ? "✔" : "✖");
	menu.AddItem(NULL_STRING, sItemTitle);

	FormatEx(sItemTitle, sizeof(sItemTitle), "%T", "MenuRadius", client);
	Format(sItemTitle, sizeof(sItemTitle), "%s [%i юнит]", sItemTitle, iHideUnits[client]);
	menu.AddItem(NULL_STRING, sItemTitle);

	menu.ExitButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Handler(Menu menu, MenuAction action, int param, int param2) {
	if(action == MenuAction_Select) {
		switch(param2) {
			case 0: { // toggle hide
				bHide[param] = !bHide[param];
				SetClientCookie(param, hCookie[0], bHide[param] ? "1" : "0");
				
				SetGlobalTransTarget(param);
				CPrintToChat(param, "%t %t", "Prefix", "Toggle", bHide[param] ? "On" : "Off");
				
				ShowMenu(param);
			}
			case 1: { // select radius of hiding
				bSelect[param] = true;
				
				SetGlobalTransTarget(param);
				CPrintToChat(param, "%t %t", "Prefix", "OnSelectStart");
			}
		}
	}
	if(action == MenuAction_End)
		delete menu;
}

public void CookieHandler(int iClient, CookieMenuAction action, any info, char[] buffer, int maxlen) {
	if(action == CookieMenuAction_DisplayOption)
		FormatEx(buffer, maxlen, "%T", "MenuTitle", iClient);
	if(action == CookieMenuAction_SelectOption)
		ShowMenu(iClient);
}
