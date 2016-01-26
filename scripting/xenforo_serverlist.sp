#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <multicolors>
#include <extended_logging>
#include <xenforo/xenforo_api>

//New Syntax
#pragma newdecls required

//Defines
#define PLUGIN_NAME     "XenForo Servers List"
#define PLUGIN_AUTHOR   "Keith Warren(Drixevel)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"List all servers and allow connections to them."
#define PLUGIN_CONTACT  "http://www.drixevel.com/"

Handle hMenu;

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_CONTACT
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_servers", ServersList);
	
	hMenu = CreateMenu(MenuHandler);
	SetMenuTitle(hMenu, "Pick a Server:");
	SetMenuExitButton(hMenu, true);
}

public void OnConfigsExecuted()
{
	if (XenForo_IsConnected())
	{
		char sQuery[1024];
		FormatEx(sQuery, sizeof(sQuery), "SELECT option_value FROM `xf_option` WHERE option_id = 'stentor_server_ips' ");
		XenForo_TQuery(QueryServers, sQuery);
	}
}

public Action ServersList(int client, int args)
{
	if (!IsClientInGame(client))
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int QueryServers(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		XenForo_LogToFile(TRACE, "Error parsing servers: '%s'", error);
		return;
	}
	
	while (SQL_FetchRow(hndl))
	{
		char sIP[256];
		SQL_FetchString(hndl, 0, sIP, sizeof(sIP));
		
		AddMenuItem(hMenu, sIP, sIP);
	}
}

public int MenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
} 