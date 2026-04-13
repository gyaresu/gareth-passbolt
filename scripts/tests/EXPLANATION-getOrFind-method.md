# Explanation: `getOrFind()` Method and the MFA Cache Bug

## How `getOrFind()` Works

### The Method Signature

```54:65:../passbolt-browser-extension/src/all/background_page/model/organizationSettings/organizationSettingsModel.js
  /**
   * Returns the organization settings from the local cache or requests the server.
   * @param {boolean} refreshCache Should request the API to retrieve the organization settings and refresh the cache.
   * Default false
   * @returns {Promise<OrganizationSettingsEntity>}
   */
  async getOrFind(refreshCache = false) {
    if (refreshCache || !_settings) {
      _settings = await this.find();
    }
    return _settings;
  }
```

### Key Behavior

1. **Default Parameter**: `refreshCache = false` means it defaults to using cached data
2. **Cache Check**: Only fetches from API if:
   - `refreshCache = true` (explicitly requested), OR
   - `_settings` is `null` (cache is empty)
3. **Static Cache**: `_settings` is a module-level variable, shared across all instances

### The Caching Mechanism

```18:19:../passbolt-browser-extension/src/all/background_page/model/organizationSettings/organizationSettingsModel.js
// Settings local cache.
let _settings;
```

This is a **static cache** - once set, it persists until:
- Explicitly flushed with `flushCache()`
- The extension is reloaded
- `refreshCache = true` is passed to `getOrFind()`

## The Problem

### Scenario That Causes the Bug

1. **Initial Load**: Extension loads, calls `getOrFind()` → fetches org settings from API → caches old Duo config
2. **Admin Updates**: Admin updates Duo settings in database (22:56:26)
3. **User Action**: User tries to enable MFA (22:56:38)
4. **Cache Hit**: Code calls `getOrFind()` without `refreshCache = true` → returns **cached old settings**

### Real-World Usage Examples

**Problematic Usage** (uses cache by default):
```javascript
// From findUserKeyPoliciesSettingsService.js line 45
const organizationSettings = await this.organizationSettingsModel.getOrFind();
// ❌ No refreshCache parameter = defaults to false = uses cache
```

**Correct Usage** (forces refresh):
```javascript
// From organizationSettingsEvents.js line 29
const organizationSettings = await organizationSettingsModel.getOrFind(refreshCache);
// ✅ refreshCache defaults to true in the event handler
```

**Also Correct**:
```javascript
// From getOrganizationSettingsController.js
return this.organizationSettingsModel.getOrFind(true);
// ✅ Explicitly passes true to force refresh
```

## Why This Design?

The caching is intentional for **performance**:
- Organization settings rarely change
- Reduces API calls
- Faster response times

However, it creates a **stale data problem** when:
- Settings are updated on the server
- Code doesn't explicitly refresh the cache
- Multiple parts of the codebase call `getOrFind()` without refresh

## The Bug Flow

```
Time 22:56:26: Admin updates Duo settings in database
  ↓
Database now has: api-25e9f1fb.duosecurity.com, DICPIC95F13UWR1FR5SJ
  ↓
Browser extension cache still has: OLD Duo settings
  ↓
Time 22:56:38: User clicks "Enable MFA"
  ↓
MFA setup code calls: getOrFind()  // No refreshCache parameter
  ↓
Returns: Cached old Duo settings ❌
  ↓
User sees: Old Duo account configuration
```

## Solutions

### 1. Force Refresh on Critical Operations
When MFA setup is initiated, always refresh:
```javascript
await organizationSettingsModel.getOrFind(true); // Force refresh
```

### 2. Clear Cache on Settings Update
When org settings are updated via admin panel:
```javascript
OrganizationSettingsModel.flushCache(); // Clear cache
```

### 3. Change Default Behavior (Breaking Change)
Change default to `refreshCache = true`, but this would increase API calls.

### 4. Add Cache Invalidation Events
Listen for organization settings updates and auto-flush cache.

## Current State

- **Event Handler**: Defaults to `refreshCache = true` ✅
- **Direct Model Usage**: Defaults to `refreshCache = false` ❌
- **Many Services**: Call `getOrFind()` without parameter = use cache ❌

The inconsistency between the event handler (refreshes by default) and direct model usage (caches by default) is the root cause of the bug.

