# AD FS Provider Code Evidence - Microsoft/UPN Specific Implementation

This document shows the actual API code that proves the AD FS provider is specifically configured for Microsoft AD FS with UPN support and Microsoft-specific handling.

## 1. UPN Email Claim - Hardcoded Default

### Evidence: `AdfsProvider.php` (Line 39)

```39:39:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Utility/Adfs/Provider/AdfsProvider.php
    public string $emailClaim = SsoSetting::ADFS_EMAIL_CLAIM_UPN;
```

The AD FS provider **hardcodes** the email claim to `upn` (User Principal Name), which is Microsoft's standard identifier.

### Evidence: `SsoSetting.php` (Line 74)

```74:74:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Model/Entity/SsoSetting.php
    public const ADFS_EMAIL_CLAIM_UPN = 'upn';
```

The constant is defined specifically for AD FS, separate from Azure (which supports multiple claims).

### Evidence: `AdfsResourceOwner.php` (Lines 37-38)

```37:38:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Utility/Adfs/ResourceOwner/AdfsResourceOwner.php
        // Default is upn
        $this->emailClaimField = $emailClaimField ?? SsoSetting::ADFS_EMAIL_CLAIM_UPN;
```

The resource owner defaults to UPN if no claim is specified, with an explicit comment noting this is the default.

## 2. Form Validation - Only UPN Allowed

### Evidence: `SsoSettingsAdfsDataForm.php` (Lines 24-46)

```24:46:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Form/SsoSettingsAdfsDataForm.php
    /**
     * Supported email claims.
     */
    public const SUPPORTED_EMAIL_CLAIM = [SsoSetting::ADFS_EMAIL_CLAIM_UPN];

    /**
     * @inheritDoc
     */
    protected function getDataValidator(): Validator
    {
        $dataValidator = parent::getDataValidator();

        $dataValidator
            ->notEmptyString('email_claim', __('The email claim should not be empty.'))
            ->maxLength('email_claim', 64, __('The email claim is too large.'))
            ->inList(
                'email_claim',
                self::SUPPORTED_EMAIL_CLAIM,
                __(
                    'The email claim should be one of the following: {0}.',
                    implode(', ', self::SUPPORTED_EMAIL_CLAIM)
                )
            );

        return $dataValidator;
    }
```

**Key Point**: The form validation **only allows** `upn` as a valid email claim. Unlike Azure (which supports `email`, `preferred_username`, and `upn`), AD FS is restricted to UPN only.

## 3. Microsoft-Specific Error Handling

### Evidence: `AdfsProvider.php` (Lines 54-61)

```54:61:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Utility/Adfs/Provider/AdfsProvider.php
    protected function checkResponse(ResponseInterface $response, $data): void
    {
        try {
            parent::checkResponse($response, $data);
        } catch (OAuth2Exception $e) {
            // Map OAuth2 exception with ADFS exception
            throw new AdfsException($data['error'], $data['error_description']);
        }
    }
```

AD FS has its own exception class (`AdfsException`) that wraps OAuth2 exceptions, providing Microsoft-specific error handling.

### Evidence: `AdfsException.php`

```21:30:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Error/Exception/AdfsException.php
class AdfsException extends OAuth2Exception
{
    /**
     * @return void
     */
    protected function logError(): void
    {
        Log::error('Unknown ADFS error: ' . $this->error);
    }
}
```

AD FS errors are logged with "ADFS" prefix, making it clear they're Microsoft-specific errors.

## 4. AD FS-Specific Service Implementation

### Evidence: `SsoAdfsService.php` (Lines 39-63)

```39:63:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Service/Sso/Adfs/SsoAdfsService.php
    protected function getOAuthProvider(SsoSettingsDto $settings): AbstractProvider
    {
        /** @var \Passbolt\Sso\Model\Dto\SsoSettingsAdfsDataDto $data */
        $data = $settings->data;

        $collaborators = [];
        $httpClient = $this->getCustomHttpClient();
        // Set custom HTTP client when using self-signed SSL certificate
        if ($httpClient instanceof Client) {
            $collaborators['httpClient'] = $httpClient;
        }

        return SsoProviderFactory::create(
            AdfsProvider::class,
            [
                'clientId' => $data->client_id,
                'clientSecret' => $data->client_secret,
                'redirectUri' => Router::url('/sso/adfs/redirect', true),
                'openIdBaseUri' => $data->url,
                'openIdConfigurationPath' => $data->openid_configuration_path,
                'emailClaim' => $data->email_claim,
            ],
            $collaborators
        );
    }
```

**Key Points**:
1. Uses `AdfsProvider::class` specifically (not generic OAuth2Provider)
2. Redirect URI is hardcoded to `/sso/adfs/redirect` (AD FS specific endpoint)
3. Passes `email_claim` from settings (which must be `upn`)

### Evidence: Provider Validation (Lines 68-83)

```68:83:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Service/Sso/Adfs/SsoAdfsService.php
    protected function assertAndGetSsoSettings(): SsoSettingsDto
    {
        try {
            $ssoSettings = (new SsoSettingsGetService())->getActiveOrFail(true);
            if ($ssoSettings->provider !== SsoSetting::PROVIDER_ADFS) {
                throw new BadRequestException(__('Invalid provider. Expected AD FS.'));
            }
            if (!($ssoSettings->data instanceof SsoSettingsAdfsDataDto)) {
                throw new BadRequestException(__('Invalid provider data. Expected AD FS settings.'));
            }
        } catch (Exception $exception) {
            throw new BadRequestException(__('No valid SSO settings found.'), 400, $exception);
        }

        return $ssoSettings;
    }
```

The service **validates** that the provider is specifically AD FS and uses AD FS-specific data DTOs.

## 5. Comparison: AD FS vs Generic OAuth2

### Generic OAuth2 Resource Owner (Flexible)

```57:62:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Utility/OAuth2/ResourceOwner/OAuth2ResourceOwner.php
    public function getEmail(): ?string
    {
        $emailClaim = Configure::read('passbolt.plugins.sso.security.oauth2.emailClaimAlias') ?? 'email';

        return $this->data[$emailClaim] ?? null;
    }
```

Generic OAuth2:
- Uses environment variable `PASSBOLT_PLUGINS_SSO_SECURITY_OAUTH2_EMAIL_CLAIM_ALIAS` (configurable)
- Defaults to `email` if not set
- Returns `null` if claim not found (non-strict)

### AD FS Resource Owner (Strict UPN)

```47:59:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Utility/Adfs/ResourceOwner/AdfsResourceOwner.php
    public function getEmail(): string
    {
        if (!isset($this->data[$this->emailClaimField]) || is_null($this->data[$this->emailClaimField])) {
            $msg = __('Single sign-on failed.') . ' ';
            $msg .= __(
                'The {0} claim is not present, please contact your administrator.',
                $this->emailClaimField
            );
            throw new BadRequestException($msg);
        }

        return $this->data[$this->emailClaimField];
    }
```

AD FS:
- **Hardcoded** to use `upn` (via `$this->emailClaimField`)
- **Throws exception** if UPN claim is missing (strict validation)
- **Returns string** (never null) - enforces email presence

## 6. AD FS-Specific Data Transfer Object

### Evidence: `SsoSettingsAdfsDataDto.php`

```26:52:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Model/Dto/SsoSettingsAdfsDataDto.php
class SsoSettingsAdfsDataDto extends SsoSettingsOAuth2DataDto
{
    /**
     * @var string
     */
    public string $email_claim;

    /**
     * Constructor.
     *
     * @param array $data with
     *  - url string
     *  - client_id string
     *  - client_secret string
     *  - openid_configuration_path string
     *  - scope string
     *  - email_claim string
     * @return void
     */
    public function __construct(array $data)
    {
        // Set common fields
        parent::__construct($data);

        // Set ADFS specific fields
        $this->email_claim = $data['email_claim'] ?? SsoSetting::ADFS_EMAIL_CLAIM_UPN;
    }
```

AD FS has its own DTO that:
- Extends generic OAuth2 DTO (inherits base fields)
- Adds `email_claim` field specific to AD FS
- Defaults to `ADFS_EMAIL_CLAIM_UPN` if not provided

## 7. Provider Type Constant

### Evidence: `SsoSetting.php` (Line 50)

```50:50:../passbolt-pro-api/plugins/PassboltEe/Sso/src/Model/Entity/SsoSetting.php
    public const PROVIDER_ADFS = 'adfs';
```

AD FS is a **first-class provider type**, separate from:
- `PROVIDER_AZURE = 'azure'`
- `PROVIDER_GOOGLE = 'google'`
- `PROVIDER_OAUTH2 = 'oauth2'`

## Summary

The code proves that AD FS is **not** just a generic OAuth2 provider. It has:

1. ✅ **Dedicated provider class** (`AdfsProvider`)
2. ✅ **UPN hardcoded** as the email claim (cannot be changed)
3. ✅ **Form validation** that only allows UPN
4. ✅ **Microsoft-specific error handling** (`AdfsException`)
5. ✅ **Strict validation** (throws exception if UPN missing)
6. ✅ **AD FS-specific DTO** with UPN default
7. ✅ **Dedicated redirect endpoint** (`/sso/adfs/redirect`)
8. ✅ **Provider type constant** (`PROVIDER_ADFS`)

This is a **Microsoft AD FS-specific implementation**, not a generic OAuth2 setup.


