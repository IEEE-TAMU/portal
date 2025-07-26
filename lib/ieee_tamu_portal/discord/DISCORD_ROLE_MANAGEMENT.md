# Discord Role Management System

This system automatically manages Discord roles for IEEE TAMU Portal members based on their authentication status and payment/registration status.

## Overview

The Discord role management system consists of several components:

1. **Discord API Client** (`IeeeTamuPortal.Discord.Client`) - Handles communication with the Discord bot API
2. **Role Manager** (`IeeeTamuPortal.Discord.RoleManager`) - Contains business logic for role assignment
3. **Role Sync Service** (`IeeeTamuPortal.Discord.RoleSyncService`) - Background service for periodic synchronization

## Features

- **Automatic Role Assignment**: Members who link their Discord account and have paid registration automatically get the "Member" role
- **Role Removal**: Members who unlink Discord or lose paid status have the "Member" role removed
- **Background Synchronization**: Periodic checks ensure roles stay in sync
- **Event-Driven Updates**: Role changes triggered immediately when:
  - Discord accounts are linked/unlinked
  - Payment status changes (payment received or override toggled)

## Configuration

### Environment Variables

The system requires these environment variables:

#### Development (optional, with defaults)
```bash
DISCORD_BOT_URL=http://localhost:3000  # Default Discord bot API URL
```

#### Production (required)
```bash
DISCORD_BOT_URL=https://your-discord-bot.example.com  # Discord bot API URL
```

### Discord Bot API

The system expects a Discord bot API running with these endpoints:

- `GET /health` - Health check
- `GET /roles?userId=USER_ID` - Get user roles
- `PUT /roles/manage` - Add role (JSON body: `{userId, roleName}`)
- `DELETE /roles/manage` - Remove role (JSON body: `{userId, roleName}`)

## Usage

### Automatic Operations

The system automatically handles role synchronization when:

1. **Discord Account Linking**: When a member links their Discord account via OAuth
2. **Discord Account Unlinking**: When a member unlinks their Discord account
3. **Payment Status Changes**: When payments are processed or payment overrides are toggled
4. **Periodic Sync**: Every 6 hours (configurable in `RoleSyncService`)

### Manual Operations

#### Force Sync All Members
```elixir
# Synchronize all Discord-linked members
{:ok, summary} = IeeeTamuPortal.Discord.RoleSyncService.force_sync_all()
```

#### Sync Specific Member
```elixir
# Synchronize a specific member
member = IeeeTamuPortal.Accounts.get_member!(123)
IeeeTamuPortal.Discord.RoleSyncService.sync_member(member)
```

#### Check if Member Should Have Role
```elixir
member = IeeeTamuPortal.Accounts.get_member!(123)
should_have_role = IeeeTamuPortal.Discord.RoleManager.should_have_member_role?(member)
```

### Admin Panel Integration

The system automatically triggers when administrators:
- Toggle payment overrides in the admin panel
- Process payments that get associated with registrations

## Role Assignment Logic

A member receives the "Member" Discord role if and only if:

1. **Discord Account Linked**: Member has linked their Discord account via OAuth
2. **Valid Registration**: Member has a paid registration for the current academic year
   - Either has an associated payment record
   - Or has payment override enabled by an administrator

## Database Schema

### Tables Used

- `secondary_auth_methods` - Stores Discord account links
- `registrations` - Stores member registrations per year
- `payments` - Stores payment records linked to registrations

### New Indexes Added

- `registrations_member_year_index` - For efficient payment status queries
- `auth_methods_provider_index` - For Discord account queries
- `auth_methods_provider_member_index` - For efficient member-Discord joins

## Monitoring and Logging

The system provides comprehensive logging:

- **Info Level**: Successful role additions/removals, sync completion
- **Warning Level**: Failed individual member syncs (continues processing others)
- **Error Level**: Discord bot connectivity issues, malformed responses

### Log Examples

```
[info] Successfully added Member role to Discord user 123456789 for member 42
[info] Discord role synchronization complete: %{total: 150, roles_added: 3, roles_removed: 1, no_change: 145, errors: 1}
[error] Failed to connect to Discord bot: connection refused
```

## Error Handling

The system gracefully handles:

- Discord bot downtime (logs errors, continues operation)
- Network connectivity issues
- Individual member sync failures (doesn't stop bulk operations)
- Missing Discord accounts (skips non-Discord members)

## Testing

### Manual Testing

1. Link a Discord account for a test member
2. Ensure member has paid registration status
3. Check Discord server for "Member" role assignment
4. Toggle payment override or unlink Discord account
5. Verify role is removed

### Force Sync Testing

```elixir
# In IEx console
{:ok, summary} = IeeeTamuPortal.Discord.RoleSyncService.force_sync_all()
IO.inspect(summary)
```

## Troubleshooting

### Common Issues

1. **Discord Bot Not Responding**
   - Check `DISCORD_BOT_URL` environment variable
   - Verify Discord bot is running and accessible
   - Check network connectivity

2. **Roles Not Syncing**
   - Verify member has Discord account linked
   - Check member's payment/registration status
   - Review application logs for errors

3. **Performance Issues**
   - Monitor database query performance
   - Consider adjusting sync interval if needed
   - Review database indexes

### Health Checks

```elixir
# Check Discord bot connectivity
{:ok, status} = IeeeTamuPortal.Discord.Client.health_check()

# Check if member should have role
member = IeeeTamuPortal.Accounts.get_member!(123)
should_have = IeeeTamuPortal.Discord.RoleManager.should_have_member_role?(member)
```

## Future Enhancements

Potential improvements:
- Support for multiple Discord roles (Officer, Volunteer, etc.)
- Role assignment based on member info (graduation year, major, etc.)
- Discord activity tracking and role expiration
- Bulk member import/export for Discord management
