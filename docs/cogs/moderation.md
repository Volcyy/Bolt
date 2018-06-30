# Moderation
This page showcases the general moderational tools available at your disposal. Infraction management and automod configuration documentation is available on their own pages.


## Commands
### `.warn <user:member> <reason:str...>`
Warns the given user for the specified reason. The warning is stored in the infraction database, and can be retrieved later.
Requires the `MANAGE_MESSAGES` permission.
```js
// Warn the mentioned member for the given reason.
.warn @Guy spamming #general with nonsense

// Warn a member by their ID instead.
.warn 252908391075151874 repeated spamming in voice chat
```

### `.temprole <user:member> <role:role> <duration:duration> [reason:str...]`
Temporarily applies the given role to the given user. Bolt will remove the role after the given duration.
An infraction will be created and stored in the infraction database.
If the role is removed from the member manually while the temprole is active, Bolt will not attempt to automatically remove it. If this happens, Bolt logs it under *INFRACTION_UPDATE*.
Requires the `MANAGE_ROLES` permission.
```js
// Apply the given role to the given user for 2 hours.
.temprole @Guy Muted 2h

// Same as above, but use the member's ID instead of a direct mention.
.temprole 252908391075151874 Muted 2h

// Same as above, but provide a reason.
.temprole @Guy Muted 2h spamming #general with nonsense after prior warning
```

### `.kick <user:member> [reason:str...]`
Kicks the given member with an optional reason.
An infraction will be created and stored in the infraction database.
Requires the `KICK_MEMBERS` permission.
```js
// Kick the given user.
.kick @Guy

// Same as above, but provide a reason
.kick @Guy complaining about repeated punishments to write documentation
```

### `.tempban <user:snowflake|member> <duration:duration> [reason:str...]`
Temporarily bans the given user with an optional reason. Bolt will remove the ban after the given duration.
An infraction will be created and stored in the infraction database.
If the user is not a member of the guild, it's possible to directly pass the ID as the `user` argument.
Requires the `BAN_MEMBERS` permission.
```js
// Temporarily ban the given user for 2 days.
.tempban @Guy 2d

// Same as above, but use the member's ID instead of a direct mention.
.tempban 252908391075151874 2d

// Same as above, but provide a reason.
.tempban @Guy 2d escalation from previous kick
```

### `.ban <user:snowflake|member> [reason:str...]`
Bans the given user with an optional reason.
An infraction will be created and stored in the infraction database.
If the user is not a member of the guild, it's possible to directly pass the ID as the `user` argument.
Requires the `BAN_MEMBERS` permission.
```js
// Permanently ban the given user.
.ban @Guy

// Same as above, but use the member's ID instead of a direct mention.
.ban 252908391075151874

// Same as above, but provide a reason.
.ban @Guy repeated spamming after multiple warnings
```