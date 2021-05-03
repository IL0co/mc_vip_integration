#include <sourcemod>
#include <mc_core>
#include <vip_core>
#include <clientprefs>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name		= "[Multi-Core] VIP Integration",
	author	  	= "iLoco",
	description = "Интеграция Multi-Core в VIP Core By R1KO",
	version	 	= "0.0.0",
	url			= "http://hlmod.ru"
};

bool g_bPreviewMode[MAXPLAYERS+1];
char g_cLastSeePluginUnique[MAXPLAYERS+1][MAX_UNIQUE_LENGTH];
StringMap g_mapCookies;

#define CORE_TYPE "vip"

public void OnPluginEnd()
{
    VIP_UnregisterMe();
	MC_UnRegisterMe();
}

public void MC_OnPluginUnRegistered(const char[] plugin_id)
{
	Cookie cookie;
	if(g_mapCookies.GetValue(plugin_id, cookie) && cookie)
	{
		g_mapCookies.Remove(plugin_id);
		delete cookie;
	}
		
    if(VIP_IsValidFeature(plugin_id))
        VIP_UnregisterFeature(plugin_id);
}

public void OnPluginStart()
{
	g_mapCookies = new StringMap();
	LoadTranslations("mc_core.phrases");

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded();
}

public void MC_OnCoreLoaded()
{
	MC_RegisterIntegration(CORE_TYPE, CallBack_MC_OnIntegrationGetItem);
}

public bool CallBack_MC_OnIntegrationGetItem(int client, const char[] plugin_id, char[] buffer, int maxlen)
{
	Cookie cookie;
	g_mapCookies.GetValue(plugin_id, cookie);
	cookie.Get(client, buffer, maxlen);

	if(buffer[0])
		return true;

	return false;
}

public void MC_OnPluginRegistered(const char[] plugin_id)
{
	char buff[MAX_UNIQUE_LENGTH];
	FormatEx(buff, sizeof(buff), "VIP:%s", plugin_id);

	g_mapCookies.SetValue(plugin_id, new Cookie(buff, buff, CookieAccess_Private));

	Load_Vip(plugin_id);
}

public void VIP_OnVIPLoaded()
{
    ArrayList ar = MC_GetPluginIdsArrayList();
	char plugin_id[MAX_UNIQUE_LENGTH];

	for(int index; index < ar.Length; index++)
	{
		ar.GetString(index, plugin_id, sizeof(plugin_id));
		Load_Vip(plugin_id);
	}
	
	delete ar;
}

void Load_Vip(const char[] plugin_id)
{
	if(!plugin_id[0] || VIP_IsValidFeature(plugin_id))
		return;
	
	VIP_RegisterFeature(plugin_id, STRING, SELECTABLE, CallBack_VIP_OnItemSelected, CallBack_VIP_OnItemDisplayed, .bCookie = false);
}

public bool CallBack_VIP_OnItemDisplayed(int client, char[] plugin_id, char[] display, int maxlength)
{   
	if(!MC_GetPluginDisplayName(client, plugin_id, CORE_TYPE, display, maxlength))
        return false;
    
    if(MC_IsPluginHavePreviewItems(plugin_id))
    {   
        char buffer[MAX_UNIQUE_LENGTH];
        Format(display, maxlength, "%s%T", display, (MC_GetClientSelectedItem(client, plugin_id, CORE_TYPE, buffer, sizeof(buffer)) ? "ENABLED" : "DISABLED"), client);
    }

	return true;
}

public bool CallBack_VIP_OnItemSelected(int client, const char[] plugin_id)
{
	if(!MC_IsValidPluginUnique(plugin_id))
		return false;

	if(!MC_CallPluginSelected(client, plugin_id, CORE_TYPE))
		return true;

	if(MC_IsPluginHavePreviewItems(plugin_id))
	{
        char buffer[MAX_UNIQUE_LENGTH];

		Cookie cookie;
		g_mapCookies.GetValue(plugin_id, cookie);
		cookie.Get(client, buffer, sizeof(buffer));

		if(buffer[0])
		{
            cookie.Set(client, "");
		}
		else
		{
			char item_unique[MAX_UNIQUE_LENGTH];
			VIP_GetClientFeatureString(client, plugin_id, item_unique, sizeof(item_unique));

            cookie.Set(client, item_unique);
		}

		return true;
	}

	g_bPreviewMode[client] = false;

	Menu_Vip_SelectItem(client, plugin_id).Display(client, 0);
	Format(g_cLastSeePluginUnique[client], sizeof(g_cLastSeePluginUnique[]), plugin_id);

	return false;
}

public Menu Menu_Vip_SelectItem(int client, const char[] plugin_id)
{
/* 
	Имя идентификатора плагина

	Превью режим [Вкл/Выкл]
	Выключить [Выбрано]

	Перечисление предметов...

	Назад
	Выход
*/
	char buff[256], translate[128], selected_item[MAX_UNIQUE_LENGTH];
	bool selected;

    MC_GetClientSelectedItem(client, plugin_id, CORE_TYPE, selected_item, sizeof(selected_item));

	Menu menu = new Menu(MenuHandler_Vip_SelectItem);
	menu.ExitBackButton = true;

    MC_GetPluginDisplayName(client, plugin_id, CORE_TYPE, translate, sizeof(translate));
	Format(translate, sizeof(translate), "%s\n ", translate);
	menu.SetTitle(translate);

	if(MC_IsPluginHavePreviewItems(plugin_id))
	{
		Format(translate, sizeof(translate), "%T%T", "PREVIEW MODE", client, (g_bPreviewMode[client] ? "ENABLED" : "DISABLED"), client);
		menu.AddItem("p", translate);
	}

	if(!selected_item[0])
		Format(translate, sizeof(translate), "%T", "SELECTED", client);
	else 
		translate[0] = '\0';
		
	Format(translate, sizeof(translate), "%T%s\n ", "DISABLE", client, translate);
	menu.AddItem("o", translate, (g_bPreviewMode[client] || !selected_item[0]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	VIP_GetClientFeatureString(client, plugin_id, buff, sizeof(buff));

	if(strcmp(buff, "all", false) == 0)
	{
		ArrayList ar = MC_GetPluginItemsArrayList(plugin_id);
		char item[MAX_UNIQUE_LENGTH];

		for(int num; num < ar.Length; num++)
		{
			ar.GetString(num, item, sizeof(item));

			if(g_bPreviewMode[client] && !MC_IsItemHavePreview(plugin_id, item))
				continue;

			selected = (strcmp(selected_item, item) == 0);
			Fill_MenuByItems(menu, client, selected, plugin_id, item);
		}
	}
	else
	{
		char exp[64][MAX_UNIQUE_LENGTH];
		int count = ExplodeString(buff, ";", exp, sizeof(exp), sizeof(exp[]));

		for(int num; num < count; num++)
		{
			if(g_bPreviewMode[client] && !MC_IsItemHavePreview(plugin_id, exp[num]))
				continue;

			selected = (strcmp(selected_item, exp[num]) == 0);
			Fill_MenuByItems(menu, client, selected, plugin_id, exp[num]);
		}
	}

	return menu;
}

void Fill_MenuByItems(Menu menu, int client, bool selected, const char[] plugin_id, char[] item_unique)
{
	char buff[128];
    MC_GetItemDisplayName(client, plugin_id, CORE_TYPE, item_unique, buff, sizeof(buff));

	if(!g_bPreviewMode[client] && selected)
	{
		Format(buff, sizeof(buff), "%s%T", buff, "SELECTED", client);
	}

	menu.AddItem(item_unique, buff, (!g_bPreviewMode[client] && selected) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
}

public int MenuHandler_Vip_SelectItem(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		char item_unique[MAX_UNIQUE_LENGTH];
		menu.GetItem(item, item_unique, sizeof(item_unique));

		if(item == 0 && item_unique[0] == 'p')
		{
			g_bPreviewMode[client] = !g_bPreviewMode[client];
		}
		else if(item_unique[0] == 'o' && (item == 0 || item == 1))
		{
			if(MC_CallItemSelected(client, g_cLastSeePluginUnique[client], item_unique, CORE_TYPE))
			{
				Cookie cookie;
				g_mapCookies.GetValue(g_cLastSeePluginUnique[client], cookie);
                cookie.Set(client, "");
			}
		}
		else if(g_bPreviewMode[client])
		{
            MC_CallItemPreview(client, g_cLastSeePluginUnique[client], item_unique, CORE_TYPE);
		}
		else
		{ 
			if(MC_CallItemSelected(client, g_cLastSeePluginUnique[client], item_unique, CORE_TYPE))
			{
				Cookie cookie;
				g_mapCookies.GetValue(g_cLastSeePluginUnique[client], cookie);
                cookie.Set(client, item_unique);
			}
		}

		Menu_Vip_SelectItem(client, g_cLastSeePluginUnique[client]).DisplayAt(client, menu.Selection, 0);
	}
	else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack) 
	{
		VIP_SendClientVIPMenu(client, false);
	}
	else if(action == MenuAction_End) 
		delete menu;
}
