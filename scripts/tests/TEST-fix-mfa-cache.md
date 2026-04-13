# Testing the MFA Cache Fix

## Understanding the Issue

The MFA setup flow calls `/mfa/setup/select` API endpoint which should return current organization settings. However, if the **web application** (not the extension) caches organization settings, it might display old Duo configuration.

## Testing Approach

### Option 1: Test via Browser Console (Quick Test)

1. **Open your browser's developer console** on `https://passbolt.local`
2. **Before testing MFA setup**, manually clear the organization settings cache:

```javascript
// In browser console, if the extension exposes this:
// This would need to be done via the extension's background page
```

### Option 2: Modify Extension to Force Cache Refresh

Add cache refresh to the MFA settings controller:

**File**: `../passbolt-browser-extension/src/all/background_page/controller/mfaPolicy/mfaGetMfaSettingsController.js`

Add this before getting MFA settings:

```javascript
import OrganizationSettingsModel from "../../model/organizationSettings/organizationSettingsModel";

// In the exec() method, add:
async exec() {
  // Force refresh organization settings cache before getting MFA settings
  const apiClientOptions = await User.getInstance().getApiClientOptions();
  const organizationSettingsModel = new OrganizationSettingsModel(apiClientOptions);
  await organizationSettingsModel.getOrFind(true); // Force refresh
  
  return this.multiFactorAuthenticationModel.getMfaSettings();
}
```

### Option 3: Test via API Directly

Test what the API returns vs what's displayed:

```bash
# Get current organization settings from API
curl -k -H "Cookie: $(get-cookie-from-browser)" \
  https://passbolt.local/settings.json

# Get MFA settings
curl -k -H "Cookie: $(get-cookie-from-browser)" \
  https://passbolt.local/mfa/setup/select.json
```

### Option 4: Database + Browser Test

1. **Check current database state**:
```bash
docker compose exec -T db mariadb -uroot -prootpassword passbolt \
  -e "SELECT property, JSON_EXTRACT(value, '$.duo.apiHostName') as api_host, 
      JSON_EXTRACT(value, '$.duo.clientId') as client_id 
      FROM organization_settings WHERE property = 'mfa';"
```

2. **Update Duo settings in org settings** (via web UI)

3. **Immediately try to enable MFA** and check if it shows:
   - ✅ New settings = Fix works
   - ❌ Old settings = Cache issue confirmed

## Recommended Test Fix

The most likely fix is to ensure the **web application** (not extension) refreshes organization settings when MFA setup is initiated. This would be in the Passbolt server code, not the extension.

However, you can test the extension side by:

1. **Building the extension with the test fix** (Option 2 above)
2. **Loading it as an unpacked extension** in Chrome/Firefox
3. **Testing the MFA setup flow**

## Building and Loading Extension for Testing

```bash
cd ../passbolt-browser-extension
npm install
npm run build:chrome-mv3  # or build:firefox
```

Then load the built extension from `dist/chrome-mv3/` as an unpacked extension in Chrome.

