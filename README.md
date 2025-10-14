# IEEE TAMU Portal

A comprehensive membership and event management system built with Phoenix LiveView for IEEE TAMU. The portal streamlines member registration, payment tracking, event management, and Discord integration for the IEEE student chapter at Texas A&M University.

[![Build Status](https://github.com/IEEE-TAMU/portal/actions/workflows/build-and-deploy.yaml/badge.svg?branch=main)](https://github.com/IEEE-TAMU/portal/actions/workflows/build-and-deploy.yaml)

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Deployment](#deployment)
- [API Documentation](#api-documentation)

## Features

### Member Management

- **Self-Service Registration**: Members create accounts, verify emails, and complete onboarding
- **Member Information System**: Track TAMU UIN, major, graduation year, t-shirt size, and more
- **Payment Tracking**: Automated payment verification with University SOFC Flywire integration
- **Resume Book**: Members upload PDFs for sponsor access; admins can bulk-export as ZIP
- **OAuth Integration**: Link Discord and Google accounts for streamlined access

![Member Registration Flow](docs/screenshots/member-registration.png)
*Member registration and information onboarding*

![Member Dashboard](docs/screenshots/member-dashboard.png)
*Member dashboard showing registration status and upcoming events*

### Event Management

- **Event CRUD**: Admins create and manage events with location, time, and RSVP limits
- **RSVP System**: Members can RSVP to events; capacity tracking prevents over-booking
- **QR Code Generation**: Each event gets a unique RSVP QR code for easy member sign-ups
- **Calendar Integration**: Public iCalendar feed at `/api/v1/calendar` for external apps

![Event Management](docs/screenshots/admin-events.png)
*Admin event management interface*

![Event RSVP Modal](docs/screenshots/event-rsvp.png)
*Member RSVP modal with event details*

### Check-In System

- **QR Code Scanning**: Real-time camera-based QR scanning for member check-ins
- **Event-Specific Check-Ins**: Track attendance per event throughout the academic year
- **Live Updates**: WebSocket-powered notifications when members are checked in
- **CSV Export**: Download check-in records for individual events or entire year

![QR Check-In](docs/screenshots/admin-checkin.png)
*Admin check-in interface with live QR scanner*

![Member Check-In QR](docs/screenshots/member-checkin-qr.png)
*Member's personal check-in QR code*

### Discord Integration

- **Automatic Role Management**: Members who link Discord and pay dues automatically receive the "Member" role
- **OAuth Linking**: One-click Discord account connection via OAuth2
- **Role Sync Service**: Background job ensures roles stay synchronized with payment status
- **Admin API**: RESTful endpoints for bulk role assignment and management
- **Real-Time Updates**: Role changes trigger immediately when payment status changes

![Discord Integration](docs/screenshots/discord-settings.png)
*Member settings showing Discord account linking*

See the full [Discord Role Management documentation](lib/ieee_tamu_portal/discord/DISCORD_ROLE_MANAGEMENT.md) for technical details.

### Admin Panel

- **Member Directory**: Browse, filter, and manage all members with [Flop](https://hex.pm/packages/flop) pagination
- **Payment Override**: Manually mark members as paid when needed
- **Resume Management**: Preview uploaded resumes and bulk download
- **Event Analytics**: View RSVP and check-in counts per event
- **API Key Management**: Generate and revoke API keys for external integrations
- **Settings Management**: Configure registration year and current event

![Admin Dashboard](docs/screenshots/admin-dashboard.png)
*Admin dashboard with key metrics*

![Admin Members](docs/screenshots/admin-members.png)
*Member directory with filtering and search*

### API

- **OpenAPI Specification**: Auto-generated docs at `/api/openapi`
- **Calendar Feed**: Public iCalendar endpoint for event subscriptions
- **Discord Roles API**: Programmatic role management for bulk operations
- **Payment Webhooks**: Receive and process Flywire payment notifications


## Getting Started

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [direnv](https://direnv.net/) (optional but recommended)

### Setup

1. **Clone the repository**
   ```sh
   git clone https://github.com/IEEE-TAMU/portal.git
   cd portal
   ```

2. **Activate the development environment**
   
   With `direnv`:
   ```sh
   direnv allow
   ```
   
   Without `direnv`:
   ```sh
   nix develop --extra-experimental-features "nix-command flakes"
   ```

3. **Start background services**
   ```sh
   devenv up
   ```
   
   This starts MariaDB and other services defined in [flake.nix](flake.nix).

4. **Bootstrap the application**
   ```sh
   mix setup
   ```
   
   The [`mix setup`](mix.exs) alias:
   - Installs dependencies
   - Creates and migrates the database
   - Seeds initial data (including test accounts)
   - Prepares frontend assets (Tailwind CSS + esbuild)

5. **Start the Phoenix server**
   ```sh
   iex -S mix phx.server
   ```
   
   Visit [http://localhost:4000](http://localhost:4000)

### Test Accounts

After running `mix setup`, the following test accounts are available:

- **Test Member**: `test@tamu.edu` / `password`
- **Admin Panel**:
`admin` / `password`

## Development Workflow

### Asset Compilation

Assets are automatically compiled and watched when running `mix phx.server`. Manual builds:

```sh
# Development build
mix assets.build

# Production build (minified)
mix assets.deploy
```

### Database Management

```sh
# Create and migrate
mix ecto.create
mix ecto.migrate

# Reset database
mix ecto.reset

# Seed data
mix run priv/repo/seeds.exs
```

### Code Quality

```sh
# Format code
mix format
```

## Testing

```sh
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/ieee_tamu_portal_web/live/member_login_live_test.exs
```

The test suite automatically creates and migrates the test database on first run.

## Deployment

### Docker

Build the Docker image using Nix:

```sh
nix build .#packages.x86_64-linux.docker
docker load < result
```

### Environment Variables

Required production environment variables:

```bash
# Database
DATABASE_URL=ecto://user:pass@localhost/ieee_tamu_portal_prod
POOL_SIZE=10

# Web
SECRET_KEY_BASE=<generate with mix phx.gen.secret>
PHX_HOST=portal.ieeetamu.org

# S3/R2 Storage (for resume uploads)
CLOUDFLARE_ACCOUNT_ID=<your-account-id>
CLOUDFLARE_BUCKET_NAME=<your-bucket>
CLOUDFLARE_ACCESS_KEY_ID=<your-access-key>
CLOUDFLARE_SECRET_ACCESS_KEY=<your-secret>

# OAuth
DISCORD_CLIENT_ID=<your-discord-client-id>
DISCORD_CLIENT_SECRET=<your-discord-client-secret>
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>

# Discord Bot Integration
DISCORD_BOT_URL=https://your-discord-bot.example.com

# Admin Panel
ADMIN_USERNAME=admin
ADMIN_PASSWORD=<secure-password>
```

### CI/CD

The project uses GitHub Actions for automated builds and deployments. See [.github/workflows/build-and-deploy.yaml](.github/workflows/build-and-deploy.yaml) for the full pipeline.

## API Documentation

### OpenAPI Specification

Interactive API docs are available at `/api/openapi` when the server is running.

### Calendar Feed

Subscribe to the public event calendar:

```
https://portal.ieeetamu.org/api/v1/calendar
```

### Discord Role Management

Bulk role assignment using CSV:

```sh
mix discord.roles.assign https://portal.ieeetamu.org $API_KEY roles.csv
```

See [Discord Role Management documentation](lib/ieee_tamu_portal/discord/DISCORD_ROLE_MANAGEMENT.md) for complete API details.

## Project Structure

```
├── assets/              # Frontend assets (JS, CSS)
├── config/              # Application configuration
├── lib/
│   ├── ieee_tamu_portal/          # Core business logic
│   │   ├── accounts/              # Member accounts and auth
│   │   ├── discord/               # Discord integration
│   │   ├── events/                # Event and RSVP management
│   │   ├── members/               # Member info and registrations
│   │   └── services/              # Service layer (file storage, etc.)
│   └── ieee_tamu_portal_web/      # Web layer (LiveView, controllers)
│       ├── api/                   # REST API controllers
│       ├── components/            # Reusable UI components
│       └── live/                  # LiveView modules
├── priv/
│   ├── repo/migrations/           # Database migrations
│   └── static/                    # Static assets
└── test/                          # Test suite
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

<!-- ## License

This project is maintained by IEEE TAMU. See [LICENSE](LICENSE) for details. -->

## Support

For questions or issues:
- Open a [GitHub Issue](https://github.com/IEEE-TAMU/portal/issues)
- Contact the IEEE TAMU officers at portal@ieeetamu.org
