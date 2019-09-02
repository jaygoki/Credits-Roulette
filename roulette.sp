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
#define HOUSE_WEIGHT  5.0
#define GREEN_WEIGHT  3.0
#define RED_BLACK_WEIGHT  46.0

bool HasBet[MAXPLAYERS+1]; // Stores whether client already bet during round or not
ConVar g_cvar_Profit_Percent; // Goal percent for player profit: at 5%, betting 100 credits 100 times will make 5 credits on average

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
	RegConsoleCmd("sm_rou", Command_Roulette);
	g_cvar_Profit_Percent = CreateConVar("sm_profit_percent", "0.05", "Goal percentage of profit for players"); // Defaults profit percent to 5%
	HookEvent("round_end", Event_RoundEnd);
	for (int i = 0; i < MaxClients; i++) 
    	{ 
    		HasBet[i] = false; // Defaults whether bet or not in a round to false for all players
    	}
}

public Action Event_RoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast) // On round end - resets all players' bet status
{
    for (int i = 0; i < MaxClients; i++)
    {
    	HasBet[i] = false;
    }
}

public Action Command_Roulette(int client, int args)// Called when sm_roulette is used
{
	ReplySource CommandSource = GetCmdReplySource();
	char player_bet[16]; //Player bet
	char bet_color[6]; // Color player bets on
	bool valid_color = false;
	
	GetCmdArg(1, player_bet, sizeof(player_bet));
	GetCmdArg(2, bet_color, sizeof(bet_color));
	
	if(StrEqual(bet_color, "red", false) || StrEqual(bet_color, "green", false) || StrEqual(bet_color, "black", false))// Checks if the color the player provided is valid
	{
		valid_color = true;
	}
	
	if (args != 2 || StringToInt(player_bet) == 0 || !valid_color)// Tests if client used sm_roulette correctly 
	{
		// Resulting message
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ...  "Usage: sm_roulette <bet> <color> (sm_rou may also be used)"); 
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ... "Bet is the amount of credits you would like to bet"); 
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ... "Color is the color you would like to bet on; either red, black, or green.");
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN ... "A correct bet on red or black will give you back your credits and then some; green will give you several times your bet!");
		return Plugin_Handled;
	}
	
	if (HasBet[client]) // Tests if client already bet during round
	{
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN..."You can only bet once in a round!");
		return Plugin_Handled;
	}
	
	if(StringToInt(player_bet) < 0)// Makes sure client bets a positive amount of credits
	{
		ReplyToCommand(client, XG_PREFIX_CHAT_WARN..."You must bet a positive amount of credits!");
		return Plugin_Handled;
	}
	
	bool isChat = false;//Checks if command originated from chat or console in order to print response in correct place
	if (CommandSource == SM_REPLY_TO_CHAT)//Response will be printed in console as well in most cases  
	{									 //so client doesn't have to scroll up in chat
		isChat = true;
	}
	
	DataPack data = new DataPack();
	data.WriteCell(client);
	data.WriteCell(StringToInt(player_bet));
	data.WriteCell(isChat);
	data.WriteString(bet_color);
	data.Reset();
	Store_GetCredits(GetSteamAccountID(client), GetCreditsCallback, data);
	
	return Plugin_Handled;
}

char Get_Roulette_Color() // Simulates roulette table, randomly chooses a color (red, green, or black) - 5% house edge
{
	
	int roulette_number = GetRandomInt(1, 100); // Random number 1-100, inclusive
	char color[6];
	
	// 5% chance house wins, 3% chance for green, 46% for either red or black
	if(roulette_number <= HOUSE_WEIGHT) // 1 2 3 4 5
	{
		color = "house";
	}
	else if (roulette_number > HOUSE_WEIGHT && roulette_number <= HOUSE_WEIGHT+GREEN_WEIGHT) // 6 7 8
	{ 
		color = "green";
	}
	else if (roulette_number > HOUSE_WEIGHT+GREEN_WEIGHT 
			&& roulette_number <= HOUSE_WEIGHT+GREEN_WEIGHT+RED_BLACK_WEIGHT)// the rest
	{
		color = "black";
	}
	else if (roulette_number > HOUSE_WEIGHT+GREEN_WEIGHT+RED_BLACK_WEIGHT)
	{
		color = "red";
	}
	
	return color;
}

int Calculate_Winnings(int bet, char color[6])// Calculates winnings on correct guess
{
	float green_multiplier = (1 + g_cvar_Profit_Percent.FloatValue) / (GREEN_WEIGHT / getTotalWeight()); // Math to calculate winnings based on PROFIT_PERCENT
	float red_black_multiplier = (1 + g_cvar_Profit_Percent.FloatValue) / (RED_BLACK_WEIGHT / getTotalWeight());
	float winnings;
	if(StrEqual(color, "green", false))
	{
		winnings = (green_multiplier - 1) * bet;
	}
	else if (StrEqual(color, "red", false) || StrEqual(color, "black", false))
	{
		winnings = (red_black_multiplier - 1) * bet;
	}
	
	return RoundFloat(winnings);
}

public void GetCreditsCallback(int credits, DataPack data)
{
	int client = data.ReadCell();
	int player_bet = data.ReadCell();
	bool isChat = data.ReadCell();
	char player_color[6]; 
	data.ReadString(player_color, sizeof(player_color));
	delete data; 
	
	if(credits < player_bet)// If player bets more credits than they currently have
	{
		if(isChat)
		{
		PrintToChat(client, XG_PREFIX_CHAT_WARN ... "You do not have enough credits!");
		}
		else
		{
		PrintToConsole(client, XG_PREFIX_CHAT_WARN..."You do not have enough credits!");
		}		
	}
	else 
	{
		Check_Win(player_color, player_bet, client, isChat);
	}
}

public void Check_Win(char color[6], int bet, int client, bool isChat)
{
	char house_color[6]; // Color player is betting against
	house_color = Get_Roulette_Color();
	
	if (StrEqual(house_color, color)) // Correct bet
	{
		int winnings = Calculate_Winnings(bet, house_color);
		if(isChat)
		{
		PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "Color was %s! Congratulations!", house_color);
		}
		PrintToConsole(client, XG_PREFIX_CHAT_ALERT..."Color was %s! Congratulations!", house_color);
		
		if(StrEqual(house_color, "green"))// Prints to all chat if a player hits the jackpot betting on green
		{
			char clientName[32];
			GetClientName(client, clientName, 32);
			PrintToChatAll(XG_PREFIX_CHAT_ALERT..."\x0B%s \x01has just won \x0B%i \x01credits betting on \x06green!", clientName, winnings);
		}
		
		Store_GiveCredits(GetSteamAccountID(client), winnings, GiveCreditsCallback, isChat);// Gives client their credits
		HasBet[client] = true;// Client has bet this round and may not bet again until next round
	}
	else // Incorrect bet
	{
		if(StrEqual(house_color, "house")) 
		{
			if(isChat)
			{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "House wins! Better luck next time.");
			}
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT..."House wins! Better luck next time.");
			
			Store_GiveCredits(GetSteamAccountID(client), -bet, GiveCreditsCallback, isChat);
			HasBet[client] = true;			
		}
		else
		{
			if(isChat)
			{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "Color was %s! Better luck next time.", house_color);
			}
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT..."Color was %s! Better luck next time.", house_color);
			
			Store_GiveCredits(GetSteamAccountID(client), -bet, GiveCreditsCallback, isChat);
			HasBet[client] = true;
		}
	}
}

public void GiveCreditsCallback(int accountid, int buf, bool isChat) // buf will be either the amount of credits that client wins or the amount they lose, depending if they win
{
	int client = AccountIDToIndex(accountid);
	if(client != -1)
	{
		if(buf > 0)
		{
			if(isChat)
			{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "You have just recieved \x06%i \x01Credits!", buf);// \x06 and \x0F etc. are for coloring text in chat
			}																				 // which is why they aren't included for console
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT..."You have just recieved %i Credits!", buf);
		}
		else if (buf < 0)
		{
			if(isChat)
			{
			PrintToChat(client, XG_PREFIX_CHAT_ALERT ... "You lost \x0F%i \x01Credits!", (buf * -1));
			}
			PrintToConsole(client, XG_PREFIX_CHAT_ALERT..."You lost %i Credits!", (buf * -1));
		}
	}
}

int AccountIDToIndex(int accountid) // Steam32 ID to servier client index
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

float getTotalWeight()
{
	return (HOUSE_WEIGHT + GREEN_WEIGHT + RED_BLACK_WEIGHT * 2);
}
