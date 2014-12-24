#if defined _xenforo_credits_included
  #endinput
#endif
#define _xenforo_credits_included

//Natives
/**
 * Returns or retrieves client credits off XenForo.
 *
 * @param client		Client to retrieve credits from.
 * @return		User ID Credits.
 **/
native XenForo_GrabCredits(client);

/**
 * Give client credits on XenForo.
 *
 * @param client		Client to give credits to.
 * @param amount		Amount of credits.
 * @return		True if successful, false otherwise.
 **/
native XenForo_GiveCredits(client, amount);

/**
 * Deduct client credits on XenForo.
 *
 * @param client		Client to deduct credits from.
 * @param amount		Amount of credits.
 * @return		True if successful, false if not enough credits or otherwise.
 **/
native XenForo_DeductCredits(client, amount);

public SharedPlugin:__pl_xenforo_credits = 
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