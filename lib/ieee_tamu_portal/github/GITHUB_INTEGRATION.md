# GitHub Integration

The portal integrates with GitHub in two independent ways:

1. **Member GitHub OAuth** — members link their GitHub account from account settings.
2. **Organization team sync** — a GitHub App keeps the `Members` and `Officers` teams in sync with portal status.

## Member OAuth setup

Create a GitHub OAuth App under the IEEE TAMU organization:

- **Homepage URL**: `https://portal.ieeetamu.org`
- **Authorization callback URL**: `https://portal.ieeetamu.org/auth/github/callback`

Configure:

```bash
GITHUB_CLIENT_ID=<oauth-app-client-id>
GITHUB_CLIENT_SECRET=<oauth-app-client-secret>
```

Members link GitHub while logged in from **Account Settings**. GitHub login is
available only for accounts that have already linked GitHub; the portal does
not auto-create accounts from GitHub email addresses.

The requested scopes are Assent's GitHub defaults (`read:user` and `user:email`).
No organization write permission is requested from individual users.

## GitHub App setup for team sync

Create a GitHub App owned by the IEEE TAMU organization:

1. Go to **Organization settings → Developer settings → GitHub Apps → New GitHub App**.
2. Set any homepage URL. No webhook is required.
3. Under **Organization permissions**, grant:
   - **Members**: Read and write
4. Install the app on the `IEEE-TAMU` organization.
5. Generate a private key and note the **App ID** and **Installation ID**.

Configure:

```bash
GITHUB_APP_ID=<app-id>
GITHUB_APP_INSTALLATION_ID=<installation-id>
GITHUB_APP_PRIVATE_KEY_PATH=/run/secrets/github-app.pem
# or provide PEM contents directly:
# GITHUB_APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n..."

GITHUB_ORG=IEEE-TAMU
GITHUB_MEMBERS_TEAM=members
GITHUB_OFFICERS_TEAM=officers
```

The app is used only server-side. It is never exposed to members.

## Team policy

- **Members** team: paid current-year members **or** officers/admins.
- **Officers** team: officers/admins.

Officers are expected to maintain global IEEE membership rather than pay local
branch dues, so officer status grants `Members` team membership even when the
local registration is unpaid. Admins are treated as officers.

## Synchronization

Team membership is reconciled when:

- A member links or unlinks GitHub
- A payment is created or a payment override is toggled
- A portal officer/admin role is granted or revoked
- The periodic sync runs every 6 hours
- `mix github.teams.sync` or `IeeeTamuPortal.Github.TeamSyncService.force_sync_all/0` is called

Run the initial backfill after configuring the app:

```bash
mix github.teams.sync
```

Adding a user who is not yet an organization member causes GitHub to send an
organization invitation; the team membership remains pending until accepted.
Removing a member from these teams does **not** remove them from the GitHub
organization itself.

## Testing

The GitHub API and installation-token exchange use `Req`, with request options
injectable through:

- `:github_req_opts` — client/team API requests
- A static token can be supplied with `:github_installation_token` for tests
