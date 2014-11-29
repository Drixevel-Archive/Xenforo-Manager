#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <morecolors>

//API Natives/Forwards
#include <xenforo_api>
#include <xenforo_credits>

#define PLUGIN_NAME     "XenForo Store Plugin"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_DESCRIPTION	"Store plugin for XenForo API."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"

new iCredits[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

public OnPluginStart()
{
	RegConsoleCmd("sm_store", StoreMenu, "Displays the XenForo store menu.");
}

public OnConfigsExecuted()
{

}

public Action:StoreMenu(client, args)
{
	if (!IsClientInGame(client))
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	new Handle:hMenu = CreateMenu("MenuHandle_StoreFront");
	SetMenuTitle(hMenu, "XenForo Store");
	
	new String:sCredits[64];
	Format(sCredits, sizeof(sCredits), "Credits: %i", XenForo_GrabCredits(client));
	AddMenuItem(hMenu, "", sCredits, ITEMDRAW_DISABLED);
	
	AddMenuItem(hMenu, "", "---", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "Items", "Categories");
	AddMenuItem(hMenu, "Refunds", "Refund Items");
	AddMenuItem(hMenu, "Give", "Give Items/Credits");
	AddMenuItem(hMenu, "Settings", "Settings");
	
	SetMenuExitButton(hMenu, true);
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public MenuHandle_StoreFront(Handle:hMenu, MenuAction:action, param1, param2)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			new String:sInfo[32];
			GetMenuItem(hMenu, param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "Items"))
			{
				
			}
			else if (StrEqual(sInfo, "Refunds"))
			{
				
			}
			else if (StrEqual(sInfo, "Give"))
			{
				
			}
			else if (StrEqual(sInfo, "Settings"))
			{
				
			}
		}
	case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}
}

bool:LoadConfigsFolder()
{
	
	return true;
}

bool:LoadConfig(const String:sFile[])
{
	new Handle:hConfigs = CreateKeyValues("Store_Category");
	
	if (!FileToKeyValues(hConfigs, sFile))
	{
		XenForo_LogToFile(ERROR, "Error retrieving configuration file: %s", sFile);
		CloseHandle(hConfigs);
		return false;
	}
	
	if (!KvGotoFirstSubKey(hConfigs, false))
	{
		XenForo_LogToFile(ERROR, "Error parsing configuration file: %s (Empty)", sFile);
		CloseHandle(hConfigs);
		return false;
	}
	
	new String:sName[64];
	KvGetString(hConfigs, "Name", sName, sizeof(sName), "Unknown Name");
	
	if (!KvJumpToKey(hConfigs, "Items"))
	{
		XenForo_LogToFile(ERROR, "Error parsing configuration file: %s (Empty Items Section)", sFile);
		CloseHandle(hConfigs);
		return false;
	}
	
	do {
		new String:sSectionName[64];
		KvGetSectionName(hConfigs, sSectionName, sizeof(sSectionName));
		
		new String:sDescription[256];
		KvGetString(hConfigs, "Description", sDescription, sizeof(sDescription), "Unknown Description");
		
		new price = KvGetNum(hConfigs, "Price", 0);
		new Float:fPrice = float(price);
		
		if (KvJumpToKey(hConfigs, "Callbacks"))
		{
			do {
				new String:sCallBackName[64];
				KvGetSectionName(hConfigs, NULL_STRING, sCallBackName, sizeof(sCallBackName));
				
				new String:sCallback[128];
				KvGetString(hConfigs, sCallBackName, sCallback, sizeof(sCallback));
				
				
			} while KvGotoNextKey(hConfigs, false);
			KvGoBack(hConfigs);
		}
		KvGoBack(hConfigs);
		
		if (KvJumpToKey(hConfigs, "Functions"))
		{
			if (KvJumpToKey(hConfigs, "Commands"))
			{
				do {
					new String:sCommandName[64];
					KvGetSectionName(hConfigs, NULL_STRING, sCommandName, sizeof(sCommandName));
					
					new String:sCommand[128];
					KvGetString(hConfigs, sCommandName, sCommand, sizeof(sCommand));
					
					
				} while KvGotoNextKey(hConfigs, false);
				KvGoBack(hConfigs);
			}
			KvGoBack(hConfigs);
			
			if (KvJumpToKey(hConfigs, "Pre"))
			{
				new color[4];
				KvGetColor(hConfigs, "Color", color[0], color[1], color[2], color[3]);
				
				new bool:bRespawn = bool:KvGetNum(hConfigs, "Respawn", 0);
				
				new String:sFlags[128];
				KvGetString(hConfigs, "Flags", sFlags, sizeof(sFlags));
				
				if (KvJumpToKey(hConfigs, "Chat"))
				{
					new String:sTag[128];
					KvGetString(hConfigs, "Tag", sTag, sizeof(sTag));
					
					new String:sTagColor[128];
					KvGetString(hConfigs, "Tag_Color", sTagColor, sizeof(sTagColor));
					
					new String:sNameColor[128];
					KvGetString(hConfigs, "Name_Color", sNameColor, sizeof(sNameColor));
					
					new String:sChatColor[128];
					KvGetString(hConfigs, "Chat_Color", sChatColor, sizeof(sChatColor));
				}
			}
			KvGoBack(hConfigs);
			
		}
		KvGoBack(hConfigs);
		
	} while KvGotoNextKey(hConfigs, false);
	
	CloseHandle(hConfigs);
	return true;
}