#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>

#pragma newdecls required
#pragma semicolon 1

#define XG_PREFIX_CHAT " \x0A[\x0Bx\x08G\x0A]\x01 "
#define XG_PREFIX_CHAT_ALERT " \x04[\x0Bx\x08G\x04]\x01 "
#define XG_PREFIX_CHAT_WARN " \x07[\x0Bx\x08G\x07]\x01 "
#define XG_PREFIX_CHAT_DONOR " \x10[\x0Bx\x08G\x10]\x01 "
#define PROFIT_PERCENT  0.05 //Goal for profits -  if you play the game 100 times, betting 100 credits, you will on average make 5 credits
#define HOUSE_WEIGHT  5.0
#define GREEN_WEIGHT  3.0
#define RED_BLACK_WEIGHT  46.0
const float TOTAL = 100.0; //(HOUSE_WEIGHT + GREEN_WEIGHT + 2 * RED_BLACK_WEIGHT);

ReplySource g_CommandSource[MAXPLAYERS]; //Source of command - was !roulette used from chat or console?
bool g_Bet[MAXPLAYERS]; //Stores whether client already bet during round or not



public Plugin myinfo = 
{
	name = "Credits Roulette ",
	author = "bonksnp",
	description = "Roulette plugin using credits",
	version = "1.0",
	url = "https://github.com/bonksnpx"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_roulette", Command_Roulette);
	HookEvent("round_end", Event_RoundEnd);
	for (int i = 1; i < MAXPLAYERS; i++) // Defaults whether bet or not to false for all players
    { 
    	g_Bet[i] = false;
    }
}

// On round end - resets all players' bet status
public Action Event_RoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast) 
{
    for (int i = 1; i < MAXPLAYERS; i++) 
    {
    	g_Bet[i] = false;
    }
}

// Called when sm_roulette is used
public Action Command_Roulette(int client, int args)
{
	g_CommandSource[client] = GetCmdReplySource();
	char buf1[16]; //Player bet
	char buf2[6]; // Color player bets on
	bool valid_color = false;
	
	GetCmdArg(1, buf1, sizeof(buf1));
	GetCmdArg(2, buf2, sizeof(buf2));
	
	// Checks if the color the player provided is valid
	if(StrEqual(buf2, "red", false) || StrEqual(buf2, "green", false) || StrEqual(buf2, "black", false))
	{
		valid_color = true;
	}
	
	// Tests if client used sm_roulette correctly
	if (args != 2 || StringToInt(buf1) == 0 || !valid_color) 
	{
		// Resulting message
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ...  "Usage: sm_roulette <bet> <color>"); 
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ... "Bet is the amount of credits you would like to bet"); 
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ... "Color is the color you would like to bet on; either red, black, or green.");
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ... "A correct bet on red or black will double your credits; green will give you 14x!");
		return Plugin_Handled;
	}
	else if (g_Bet[client]) UNCOMMENT THIS 
	{
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN..."You can only bet once in a round!");
		return Plugin_Handled;
	}
	else if (g_CommandSource[client] == SM_REPLY_TO_CHAT)
	{
	DataPack data = new DataPack();
	data.WriteCell(client);
	data.WriteCell(StringToInt(buf1));
	data.WriteString(buf2);
	data.Reset();
	Store_GetCredits(GetSteamAccountID(client), GetCreditsCallbackChat, data);
	g_Bet[client] = true;
	return Plugin_Handled;
	}
	else if (g_CommandSource[client] == SM_REPLY_TO_CONSOLE)
	{
	DataPack data = new DataPack();
	data.WriteCell(client);
	data.WriteCell(StringToInt(buf1));
	data.WriteString(buf2);
	data.Reset();
	Store_GetCredits(GetSteamAccountID(client), GetCreditsCallbackConsole, data);
	g_Bet[client] = true;
	return Plugin_Handled;
	}
	
	return Plugin_Handled;
}


// Simulates roulette table, randomly chooses a color (red, green, or black) - 5% house edge
char Get_Roulette_Color()
{
	// Random number 1-100, inclusive
	int roulette_number = GetRandomInt(1, 100);
	char color[6];
	
	// 5% chance house wins, 3% chance for green, 46% for either red or black
	if(roulette_number <= 5) // 1 2 3 4 5
	{
		color = "house";
	}
	else if (roulette_number > 5 && roulette_number <= 8) // 6 7 8
	{ 
		color = "green";
	}
	else if (roulette_number > 8 && roulette_number <= 54)// the rest
	{
		color = "black";
	}
	else if (roulette_number > 54)
	{
		color = "red";
	}
	
	return color;
}

// Calculates winnings on correct guess
int Calculate_Winnings(int bet, char color[6])
{
	float green_multiplier = (1 + PROFIT_PERCENT) / (GREEN_WEIGHT / TOTAL);
	float red_black_multiplier = (1 + PROFIT_PERCENT) / (RED_BLACK_WEIGHT / TOTAL);
	float winnings;
	if(StrEqual(color, "green", false))
	{
		winnings = green_multiplier * bet;
	}
	else if (StrEqual(color, "red", false) || StrEqual(color, "black", false))
	{
		winnings = red_black_multiplier * bet;
	}
	
	return RoundFloat(winnings);
}

public void GetCreditsCallbackChat(int credits, DataPack data)
{
	int client = data.ReadCell();
	int player_bet = data.ReadCell();
	char player_color[6]; 
	data.ReadString(player_color, sizeof(player_color));
	delete data; 
	
	if(credits < player_bet)
	{
		PrintToChat(client, XG_PREFIX_CHAT_WARN ... "You do not have enough credits!");
	}
	else if (player_bet < 0)
	{
		PrintToChat(client, XG_PREFIX_CHAT_WARN ... "You cannot bet negative credits!");		
	}
	else 
	{
		Check_WinChat(player_color, player_bet, client);
	}
}

public void GetCreditsCallbackConsole(int credits, DataPack data)
{
	int client = data.ReadCell();
	int player_bet = data.ReadCell();
	char player_color[6]; 
	data.ReadString(player_color, sizeof(player_color));
	delete data; 
	
	if(credits < player_bet)
	{
		PrintToConsole(client, XG_PREFIX_CHAT_WARN ... "You do not have enough credits!");
	}
	else if (player_bet < 0)
	{
		PrintToConsole(client, XG_PREFIX_CHAT_WARN ... "You cannot bet negative credits!");		
	}
	else 
	{
		Check_WinConsole(player_color, player_bet, client);
	}
}

public void Check_WinChat(char color[6], int bet, int client)
{
	char house_color[6]; // Color player is betting against
	house_color = Get_Roulette_Color();
	
	if (StrEqual(house_color, color)) // Correct bet
	{
		int winnings = Calculate_Winnings(bet, house_color);
		PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "Color was %s! Congratulations!", house_color);
		Store_GiveCredits(GetSteamAccountID(client), winnings, GiveCreditsCallbackChat);
	}
	else if (!StrEqual(house_color, color)) // Incorrect bet
	{
		if(StrEqual(house_color, "house"))
		{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "House wins! Better luck next time!");
			Store_GiveCredits(GetSteamAccountID(client), -bet, GiveCreditsCallbackChat);	
		}
		else
		{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "Color was %s! Better luck next time!", house_color);
			Store_GiveCredits(GetSteamAccountID(client), -bet, GiveCreditsCallbackChat);
		}
	}
	
}

public void Check_WinConsole(char color[6], int bet, int client)
{
	char house_color[6]; // Color player is betting against
	house_color = Get_Roulette_Color();
	
	if (StrEqual(house_color, color)) // Correct bet
	{
		int winnings = Calculate_Winnings(bet, house_color);
		PrintToConsole(client, XG_PREFIX_CHAT_ALERT ... "Color was %s! Congratulations!", house_color);
		Store_GiveCredits(GetSteamAccountID(client), winnings, GiveCreditsCallbackConsole);
	}
	else if (!StrEqual(house_color, color)) // Incorrect bet
	{
		if(StrEqual(house_color, "house"))
		{
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT ... "House wins! Better luck next time!");
			Store_GiveCredits(GetSteamAccountID(client), -bet, GiveCreditsCallbackConsole);	
		}
		else
		{
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT ... "Color was %s! Better luck next time!", house_color);
			Store_GiveCredits(GetSteamAccountID(client), -bet, GiveCreditsCallbackConsole);
		}	
	}
	
}

public void GiveCreditsCallbackChat(int accountid, int buf, any data) //buf will be either the amount of credits that client wins or the amount they lose, depending if they win
{
	int client = AccountIDToIndex(accountid);
	if(client != -1)
	{
		if(buf > 0)
		{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT..."You have just recieved %i Credits!", buf);
		}
		else if (buf < 0)
		{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT..."You lost %i Credits!", abs(buf));
		}
	}
}

public void GiveCreditsCallbackConsole(int accountid, int buf, any data) 
{
	int client = AccountIDToIndex(accountid);
	if(client != -1)
	{
		if(buf > 0)
		{
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT..."You have just recieved %i Credits!", buf);
		}
		else if (buf < 0)
		{
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT..."You lost %i Credits!", abs(buf));
		}
	}
}

int AccountIDToIndex(int accountid) //Steam32 ID to servier client index
{
    for (int i = 1; i < MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && accountid == GetSteamAccountID(i))
        {
            return i;
        }
    }
    return -1;
}

int abs(int num)//Returns absolute value of a number
{
	int ret;
	if(num >= 0)
	{
		ret = num;
	}
	else if(num < 0)
	{
		ret = num * -1;
	}
	return ret;
}


