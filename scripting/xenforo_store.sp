#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <morecolors>

//API Natives/Forwards
#include <xenforo_api>
#include <xenforo_credits>

#define PLUGIN_NAME     "XenForo Store Plugin"
#define PLUGIN_AUTHOR   "Keith Warren(Drixevel)"
#define PLUGIN_VERSION  "1.0.1"
#define PLUGIN_DESCRIPTION	"Store plugin for XenForo API."
#define PLUGIN_CONTACT  "http://www.drixevel.com/"

new Handle:hMenu_Categories = INVALID_HANDLE;
new Handle:hMenu_Category_Items[128] = {INVALID_HANDLE, ...};
new iConfigsLoaded = 0;

enum Category_Struct
{
	String:sCategoryName[64]
}
new iCategory_Indexes[128][Category_Struct];
new iCategory_Amount = 0;

enum Item_Struct
{
	iItemCategoryID,
	String:sItemName[64],
	String:sItemDescription[128],
	iItemPrice
}
new iItem_Indexes[2048][Item_Struct];
new iItem_Amount = 0;

new String:sStart_CommandString[2048][255];
//new iStart_Command[MAXPLAYERS + 1];

new String:sEnd_CommandString[2048][255];
new iEnd_Command[MAXPLAYERS + 1];

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
	
	HookEvent("teamplay_round_win", OnRoundEnd);
}

public OnConfigsExecuted()
{
	if (hMenu_Categories != INVALID_HANDLE)
	{
		CloseHandle(hMenu_Categories);
		hMenu_Categories = INVALID_HANDLE;
	}
	
	hMenu_Categories = CreateMenu(MenuHandle_Categories);
	SetMenuTitle(hMenu_Categories, "Select a category:");
	
	new String:sCategories[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sCategories, sizeof(sCategories), "configs/xenforo_store/categories_list.cfg");
	
	new Handle:kv = CreateKeyValues("Store_Categories_list");
	FileToKeyValues(kv, sCategories);
	
	KvGotoFirstSubKey(kv, false);
	
	do {
		new String:sCategory[128];
		KvGetString(kv, NULL_STRING, sCategory, sizeof(sCategory));
		
		new String:sCategory_Path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sCategory_Path, sizeof(sCategory_Path), "configs/xenforo_store/%s.cfg", sCategory);
		
		LoadConfig(sCategory_Path);
		iConfigsLoaded++;
		
	} while KvGotoNextKey(kv, false);	
}

public OnRoundEnd(Handle:hEvent, const String:sName[], bool:bBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (iEnd_Command[i] != 0)
		{
			new String:sUserID[64];
			Format(sUserID, sizeof(sUserID), "#%i", GetClientUserId(i));
			
			new String:sExecute[255];
			strcopy(sExecute, sizeof(sExecute), sEnd_CommandString[iEnd_Command[i]]);
			ReplaceString(sExecute, sizeof(sExecute), "{userid}", sUserID);
			ServerCommand(sExecute);
			
			iEnd_Command[i] = 0;
		}
	}
}

public MenuHandle_Categories(Handle:hMenu, MenuAction:action, param1, param2)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			new String:sInfo[32];
			GetMenuItem(hMenu, param2, sInfo, sizeof(sInfo));
			new category = StringToInt(sInfo);
			
			DisplayMenu(hMenu_Category_Items[category], param1, MENU_TIME_FOREVER);
		}
	}
}

public Action:StoreMenu(client, args)
{
	if (!IsClientInGame(client))
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!XenForo_IsProcessed(client))
	{
		CReplyToCommand(client, "You are not currently processed, please wait for your XenForo account to be processed.");
		return Plugin_Handled;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_StoreFront);
	SetMenuTitle(hMenu, "XenForo Store");
	
	new String:sCredits[64];
	Format(sCredits, sizeof(sCredits), "Credits: %i", XenForo_GrabCredits(client));
	AddMenuItem(hMenu, "", sCredits, ITEMDRAW_DISABLED);
	
	AddMenuItem(hMenu, "", "---", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "Categories", "Categories");
	AddMenuItem(hMenu, "Refunds", "Refund Items", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "Give", "Give Items/Credits", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "Settings", "Settings", ITEMDRAW_DISABLED);
	
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
			
			if (StrEqual(sInfo, "Categories"))
			{
				DisplayMenu(hMenu_Categories, param1, MENU_TIME_FOREVER);
			}
		}
	case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}
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
	
	new String:sName[64];
	KvGetString(hConfigs, "Name", sName, sizeof(sName), "Unknown Name");
	
	strcopy(iCategory_Indexes[iCategory_Amount][sCategoryName], 64, sName);
	
	new String:sCategory_ID[64];
	Format(sCategory_ID, sizeof(sCategory_ID), "%i", iCategory_Amount);
	AddMenuItem(hMenu_Categories, sCategory_ID, sName);
	
	if (hMenu_Category_Items[iCategory_Amount] != INVALID_HANDLE)
	{
		CloseHandle(hMenu_Category_Items[iCategory_Amount]);
		hMenu_Category_Items[iCategory_Amount] = INVALID_HANDLE;
	}
	
	hMenu_Category_Items[iCategory_Amount] = CreateMenu(MenuHandle_Category);
	SetMenuTitle(hMenu_Category_Items[iCategory_Amount], sName);
	
	if (!KvJumpToKey(hConfigs, "Items"))
	{
		XenForo_LogToFile(ERROR, "Error parsing items menu for category: '%s'", sName);
		CloseHandle(hConfigs);
		return false;
	}
	
	if (!KvGotoFirstSubKey(hConfigs, false))
	{
		XenForo_LogToFile(ERROR, "Error parsing items for category: '%s'", sName);
		CloseHandle(hConfigs);
		return false;
	}
	
	do {
		iItem_Indexes[iItem_Amount][iItemCategoryID] = iCategory_Amount;
				
		new String:sSectionName[64];
		KvGetSectionName(hConfigs, sSectionName, sizeof(sSectionName));
		strcopy(iItem_Indexes[iItem_Amount][sItemName], 64, sSectionName);
				
		new String:sDescription[256];
		KvGetString(hConfigs, "Description", sDescription, sizeof(sDescription), "Unknown Description");
		strcopy(iItem_Indexes[iItem_Amount][sItemDescription], 64, sDescription);
		
		new price = KvGetNum(hConfigs, "Price", 0);
		iItem_Indexes[iItem_Amount][iItemPrice] = price;
		
		if (KvJumpToKey(hConfigs, "Functions"))
		{
			XenForo_LogToFile(TRACE, "Jumped to 'Functions' key.");
			
			if (KvJumpToKey(hConfigs, "Commands"))
			{
				XenForo_LogToFile(TRACE, "Jumped to 'Commands' key.");
				
				if (KvJumpToKey(hConfigs, "Start"))
				{
					XenForo_LogToFile(TRACE, "Jumped to 'Start' key.");
					
					KvGotoFirstSubKey(hConfigs, false);
					do {
						new String:sStart_Command[128];
						KvGetString(hConfigs, NULL_STRING, sStart_Command, sizeof(sStart_Command));
						strcopy(sStart_CommandString[iItem_Amount], 255, sStart_Command);
						
						XenForo_LogToFile(TRACE, "%s copied to %s. [%i]", sStart_Command, sStart_CommandString[iItem_Amount], iItem_Amount);
					} while KvGotoNextKey(hConfigs, false);
					KvGoBack(hConfigs);
					
					KvGoBack(hConfigs);
				}
				
				if (KvJumpToKey(hConfigs, "End"))
				{
					XenForo_LogToFile(TRACE, "Jumped to 'End' key.");
					
					KvGotoFirstSubKey(hConfigs, false);
					do {
						new String:sEnd_Command[128];
						KvGetString(hConfigs, NULL_STRING, sEnd_Command, sizeof(sEnd_Command));
						strcopy(sEnd_CommandString[iItem_Amount], 255, sEnd_Command);
						
						XenForo_LogToFile(TRACE, "%s copied to %s. [%i]", sEnd_Command, sEnd_CommandString[iItem_Amount], iItem_Amount);
					} while KvGotoNextKey(hConfigs, false);
					KvGoBack(hConfigs);
					
					KvGoBack(hConfigs);
				}
				
				KvGoBack(hConfigs);
			}
			
			KvGoBack(hConfigs);
		}
		
		new String:sMenuItem[128];
		Format(sMenuItem, sizeof(sMenuItem), "%s [%i]", sSectionName, price);
		
		new String:sItem_ID[64];
		IntToString(iItem_Amount, sItem_ID, sizeof(sItem_ID));
		AddMenuItem(hMenu_Category_Items[iCategory_Amount], sItem_ID, sMenuItem);
		
		iItem_Amount++;
	} while KvGotoNextKey(hConfigs, false);
	
	iCategory_Amount++;
	
	CloseHandle(hConfigs);
	return true;
}

public MenuHandle_Category(Handle:hMenu, MenuAction:action, param1, param2)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			new String:sInfo[32];
			GetMenuItem(hMenu, param2, sInfo, sizeof(sInfo));
			new item = StringToInt(sInfo);
			
			XenForo_LogToFile(DEFAULT, "%N clicked on item %s. [%i]", param1, sInfo, item);
			
			new price = iItem_Indexes[item][iItemPrice];
			
			if (price > XenForo_GrabCredits(param1))
			{
				CPrintToChat(param1, "You do not have enough credits to purchase this item.");
				DisplayMenu(hMenu, param1, MENU_TIME_FOREVER);
				return;
			}
			
			XenForo_DeductCredits(param1, price);
			
			new String:sUserID[64];
			Format(sUserID, sizeof(sUserID), "#%i", GetClientUserId(param1));
			
			if (strlen(sStart_CommandString[item]) != 0)
			{				
				new String:sExecute[255];
				strcopy(sExecute, sizeof(sExecute), sStart_CommandString[item]);
				ReplaceString(sExecute, sizeof(sExecute), "{userid}", sUserID);
				ServerCommand(sExecute);
				
				iEnd_Command[param1] = item;
			}
			else
			{
				XenForo_LogToFile(ERROR, "Error executing command %s. [Empty String]", sStart_CommandString[item]);
			}
			
			XenForo_LogToFile(DEFAULT, "%N clicked on item %s. [%i] [COMPLETE]", param1, sInfo, item);
		}
	}
}