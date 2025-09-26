<?php
/**
 * Passbolt LDAP Aggregation Configuration
 * 
 * This configuration enables LDAP directory synchronization using the OpenLDAP meta backend.
 * Passbolt connects to a single unified LDAP endpoint that aggregates results from multiple
 * backend LDAP directories into a unified namespace.
 * 
 * Architecture:
 * - LDAP Meta Proxy: ldap-meta.local:3389 (unified namespace)
 * - Backend 1: Passbolt Inc. (dc=passbolt,dc=local) - Historical computing pioneers
 * - Backend 2: Example Corp (dc=example,dc=com) - Modern tech professionals
 * 
 * The meta backend provides a unified view of both directories, allowing Passbolt to
 * synchronize users and groups from both organizations through a single LDAP connection.
 */

return [
    'passbolt' => [
        'plugins' => [
            'directorySync' => [
                // Enable directory synchronization
                'enabled' => true,
                
                // Default admin user for operations
                'defaultUser' => 'ada@passbolt.com',
                
                // Default group admin for newly created groups
                'defaultGroupAdminUser' => 'ada@passbolt.com',
                
                // Sync all users (not just enabled ones)
                'enabledUsersOnly' => false,
                
                // Don't use email prefix/suffix
                'useEmailPrefixSuffix' => false,
                
                // User filter for synchronization
                'userCustomFilters' => '(|(memberof=cn=developers,ou=groups,dc=passbolt,dc=unified,dc=local)(memberof=cn=creative,ou=teams,dc=example,dc=unified,dc=local))',
                
                // Object classes for users and groups
                'groupObjectClass' => 'groupOfUniqueNames',
                'userObjectClass' => 'inetOrgPerson',
                
                // Field mappings for OpenLDAP
                'fieldsMapping' => [
                    'openldap' => [
                        'group' => [
                            'users' => 'uniqueMember'
                        ]
                    ]
                ],
                
                // Single LDAP domain configuration for aggregation proxy
                'ldap' => [
                    'domains' => [
                        'unified' => [
                            'domain_name' => 'unified.local',
                            'username' => 'cn=readonly,dc=passbolt,dc=unified,dc=local',
                            'password' => 'readonly',
                            'base_dn' => 'dc=unified,dc=local',
                            'hosts' => ['ldap-meta.local'],
                            'use_ssl' => true,
                            'port' => 636,
                            'ldap_type' => 'openldap',
                            'lazy_bind' => false,
                            'server_selection' => 'order',
                            'bind_format' => '%username%',
                            'user_path' => 'ou=users',
                            'group_path' => 'ou=groups',
                            
                            // LDAPS security options
                            'options' => [
                                LDAP_OPT_RESTART => 1,
                                LDAP_OPT_REFERRALS => 0,
                                LDAP_OPT_X_TLS_REQUIRE_CERT => LDAP_OPT_X_TLS_NEVER,
                            ],
                            'timeout' => 10,
                        ],
                    ],
                ],
            ],
        ],
    ],
];