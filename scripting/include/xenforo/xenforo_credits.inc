#if defined _xenforo_credits_included
  #endinput
#endif
#define _xenforo_credits_included

//Natives
/**
 * Returns the amount of credits owned by the client.
 *
 * @param client		client index
 *
 * @return				Credits amount owned by the client.
 **/
native int XenForo_GrabCredits(int client);

/**
 * Give client credits on XenForo.
 *
 * @param client		client index
 * @param amount		Credits amount to give.
 *
 * @return				True if successful, false otherwise.
 **/
native bool XenForo_GiveCredits(int client, int amount);

/**
 * Deduct client credits on XenForo.
 *
 * @param client		client index
 * @param amount		Credits amount to deduct.
 *
 * @return				True if successful, false if not enough credits or otherwise.
 **/
native bool XenForo_DeductCredits(client, amount);

public SharedPlugin __pl_xenforo_credits = 
{
	name = "xenforo_credits",
	file = "xenforo_credits.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_xenforo_credits_SetNTVOptional()
{
	MarkNativeAsOptional("XenForo_GrabCredits");
	MarkNativeAsOptional("XenForo_GiveCredits");
	MarkNativeAsOptional("XenForo_DeductCredits");
}
#endif