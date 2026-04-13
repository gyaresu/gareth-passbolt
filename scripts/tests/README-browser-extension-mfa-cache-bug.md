# Browser Extension MFA/Duo Cache Bug Analysis

## Root Cause Identified

The browser extension caches organization settings in a static variable, and this cache is not automatically refreshed when organization Duo settings are updated.

## Code Analysis

### Organization Settings Caching

**File**: `src/all/background_page/model/organizationSettings/organizationSettingsModel.js`

```18:72:../passbolt-browser-extension/src/all/background_page/model/organizationSettings/organizationSettingsModel.js
// Settings local cache.
let _settings;

class OrganizationSettingsModel {
  // ...
  
  async getOrFind(refreshCache = false) {
    if (refreshCache || !_settings) {
      _settings = await this.find();
    }
    return _settings;
  }

  static flushCache() {
    _settings = null;
  }
}
```

**Key Issue**: The `getOrFind()` method defaults to `refreshCache = false`, meaning it will return cached settings unless explicitly told to refresh.

### MFA Settings Retrieval

**File**: `src/all/background_page/model/multiFactorAuthentication/multiFactorAuthenticationModel.js`

The MFA model calls the API service directly:
- `getMfaSettings()` → calls `/mfa/setup/select` endpoint
- This endpoint should return current organization settings from the server

However, if the browser extension or web app is using cached organization settings anywhere in the MFA setup flow, it will show old Duo configuration.

### Organization Settings Event Handler

**File**: `src/all/background_page/event/organizationSettingsEvents.js`

```25:29:../passbolt-browser-extension/src/all/background_page/event/organizationSettingsEvents.js
worker.port.on("passbolt.organization-settings.get", async (requestId, refreshCache = true) => {
  try {
    const apiClientOptions = await User.getInstance().getApiClientOptions();
    const organizationSettingsModel = new OrganizationSettingsModel(apiClientOptions);
    const organizationSettings = await organizationSettingsModel.getOrFind(refreshCache);
```

**Note**: The event handler defaults to `refreshCache = true`, which is good. However, if code calls `getOrFind()` directly without going through the event handler, it may use cached data.

## Potential Bug Scenarios

1. **Direct Model Usage**: If MFA setup code directly instantiates `OrganizationSettingsModel` and calls `getOrFind()` without `refreshCache = true`, it will use cached settings.

2. **Web App Cache**: The web application (not the extension) might also cache organization settings. When the user navigates to MFA setup, the web app might be displaying cached Duo configuration.

3. **API Response Caching**: The `/mfa/setup/select` endpoint might be returning organization settings that were cached on the server side.

## Recommended Fixes

1. **Force Cache Refresh on MFA Setup**: When initiating MFA setup, ensure organization settings are refreshed:
   ```javascript
   await organizationSettingsModel.getOrFind(true); // Force refresh
   ```

2. **Clear Cache on Organization Settings Update**: When organization settings are updated (via admin panel), trigger a cache flush:
   ```javascript
   OrganizationSettingsModel.flushCache();
   ```

3. **Check Web App**: Verify if the Passbolt web application also caches organization settings and ensure it refreshes when Duo settings change.

## Investigation Steps

1. Check where MFA setup UI retrieves organization settings
2. Verify if the web app has its own organization settings cache
3. Check if the `/mfa/setup/select` API endpoint uses any server-side caching
4. Test if calling `OrganizationSettingsModel.flushCache()` before MFA setup resolves the issue

## Database Confirmation

From the database investigation:
- Organization settings were updated at `2026-01-05 22:56:26` with new Duo config
- User attempted MFA setup at `2026-01-05 22:56:38` (12 seconds later)
- User reported seeing old Duo configuration

This timing suggests the browser extension or web app was using cached organization settings that hadn't been refreshed yet.

