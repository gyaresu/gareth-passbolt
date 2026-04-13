-- Check MFA/Duo Configuration Bug
-- This script checks organization-level Duo settings and user-level MFA settings
-- to confirm if user MFA is using old org Duo configuration after org settings were updated

-- 1. Check organization settings for Duo configuration
SELECT 
    '=== Organization Settings ===' as section,
    property,
    JSON_EXTRACT(value, '$.duo.apiHostName') as api_host,
    JSON_EXTRACT(value, '$.duo.clientId') as client_id,
    created,
    modified
FROM organization_settings
WHERE property = 'mfa'
ORDER BY modified DESC;

-- 2. Check for MFA setup tokens (user MFA configuration attempts)
SELECT 
    '=== User MFA Setup Tokens ===' as section,
    u.username,
    at.type,
    JSON_EXTRACT(at.data, '$.provider') as provider,
    JSON_EXTRACT(at.data, '$.state') as state,
    at.created,
    at.modified,
    TIMESTAMPDIFF(SECOND, (SELECT modified FROM organization_settings WHERE property = 'mfa' LIMIT 1), at.modified) as seconds_after_org_update
FROM authentication_tokens at
JOIN users u ON u.id = at.user_id
WHERE at.type = 'mfa_setup'
ORDER BY at.modified DESC;

-- 3. Check account_settings for any MFA-related user settings
SELECT 
    '=== User Account Settings (MFA related) ===' as section,
    u.username,
    a.property,
    a.value,
    a.created,
    a.modified
FROM account_settings a
JOIN users u ON u.id = a.user_id
WHERE a.property LIKE '%mfa%' OR a.property LIKE '%duo%' OR a.property LIKE '%totp%'
   OR a.value LIKE '%duo%' OR a.value LIKE '%DICPIC%' OR a.value LIKE '%api-%'
ORDER BY a.modified DESC;

-- 4. Summary: Compare org settings update time vs user MFA setup time
SELECT 
    '=== TIMELINE COMPARISON ===' as section,
    'Org MFA Updated' as event,
    (SELECT modified FROM organization_settings WHERE property = 'mfa' LIMIT 1) as timestamp,
    JSON_EXTRACT((SELECT value FROM organization_settings WHERE property = 'mfa' LIMIT 1), '$.duo.apiHostName') as api_host,
    JSON_EXTRACT((SELECT value FROM organization_settings WHERE property = 'mfa' LIMIT 1), '$.duo.clientId') as client_id
UNION ALL
SELECT 
    '=== TIMELINE COMPARISON ===' as section,
    CONCAT('User MFA Setup: ', u.username) as event,
    at.modified as timestamp,
    NULL as api_host,
    NULL as client_id
FROM authentication_tokens at
JOIN users u ON u.id = at.user_id
WHERE at.type = 'mfa_setup'
ORDER BY timestamp DESC;

-- 5. Check for any Duo references in all tables
SELECT 
    '=== All Duo References in Database ===' as section,
    'organization_settings' as table_name,
    property,
    LEFT(value, 200) as value_preview,
    created,
    modified
FROM organization_settings
WHERE value LIKE '%duo%' OR value LIKE '%DICPIC95F13UWR1FR5SJ%' OR value LIKE '%api-25e9f1fb.duosecurity.com%'
   OR value LIKE '%api-%.duosecurity.com%'
UNION ALL
SELECT 
    '=== All Duo References in Database ===' as section,
    'account_settings' as table_name,
    a.property,
    LEFT(a.value, 200) as value_preview,
    a.created,
    a.modified
FROM account_settings a
WHERE a.value LIKE '%duo%' OR a.value LIKE '%DICPIC95F13UWR1FR5SJ%' OR a.value LIKE '%api-25e9f1fb.duosecurity.com%'
   OR a.value LIKE '%api-%.duosecurity.com%'
UNION ALL
SELECT 
    '=== All Duo References in Database ===' as section,
    'authentication_tokens' as table_name,
    at.type as property,
    LEFT(at.data, 200) as value_preview,
    at.created,
    at.modified
FROM authentication_tokens at
WHERE at.data LIKE '%duo%' OR at.data LIKE '%DICPIC95F13UWR1FR5SJ%' OR at.data LIKE '%api-25e9f1fb.duosecurity.com%'
   OR at.data LIKE '%api-%.duosecurity.com%'
ORDER BY modified DESC;

