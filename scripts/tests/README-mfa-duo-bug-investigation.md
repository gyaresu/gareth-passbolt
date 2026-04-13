# MFA/Duo Configuration Bug Investigation

## Summary

Investigation into a bug where user MFA setup shows previous Duo account configuration after organization Duo settings were updated.

## Timeline

- **2026-01-05 22:56:26**: Organization MFA settings updated with NEW Duo configuration
  - API Host: `api-25e9f1fb.duosecurity.com`
  - Client ID: `DICPIC95F13UWR1FR5SJ`
  
- **2026-01-05 22:56:38** (12 seconds later): User `ada@passbolt.com` attempted to enable MFA

## Database Findings

### Organization Settings
- **Current Configuration**: Contains the NEW Duo settings
- **Location**: `organization_settings` table, property = `mfa`
- **Value**: JSON with `apiHostName: "api-25e9f1fb.duosecurity.com"` and `clientId: "DICPIC95F13UWR1FR5SJ"`

### User MFA Configuration
- **MFA Setup Token**: Found in `authentication_tokens` table
  - Type: `mfa_setup`
  - Provider: `duo`
  - **Note**: Token does NOT contain Duo API hostname or client ID - only provider type and state
  - This suggests the system should read org settings at MFA setup time

### Key Observation
The `mfa_setup` token was created **after** the organization settings were updated, but the user reported seeing the **previous** Duo account configuration when trying to enable MFA.

## Potential Root Causes

1. **Cached Organization Settings**: The MFA setup process may be using cached organization settings that haven't been refreshed
2. **Frontend Cache**: The frontend may be displaying cached organization settings
3. **User-Specific MFA Config**: There may be user-specific MFA configuration stored elsewhere (not found in database queries)
4. **Session/Token Cache**: The authentication token or session may contain old organization settings

## Database Queries

Run the investigation script:
```bash
docker compose exec -T db mariadb -uroot -prootpassword passbolt < scripts/tests/check-mfa-duo-config.sql
```

## Next Steps for Confirmation

1. Check Passbolt application logs around 22:56:26-22:56:38 for any caching or configuration retrieval
2. Check if there's a Redis/Valkey cache that might be storing old organization settings
3. Verify if the frontend is making API calls to get organization settings or using cached values
4. Check if there are any user-specific MFA configuration records that weren't found in the database queries

## Bug Confirmation Status

**PARTIALLY CONFIRMED**: 
- Organization settings show the new configuration
- User MFA setup occurred after org update
- No user-specific MFA config found in database with old settings
- Likely a caching issue where old org settings are being used during MFA setup

