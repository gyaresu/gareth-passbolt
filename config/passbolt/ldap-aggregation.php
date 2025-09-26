<?php
/**
 * Passbolt LDAP Aggregation Configuration with LDAPS Security
 * 
 * This configuration demonstrates LDAP aggregation using OpenLDAP meta backend.
 * Passbolt connects to a single unified LDAP endpoint that aggregates results
 * from multiple backend LDAP directories.
 * 
 * Security Features:
 * - LDAPS encryption for all LDAP connections (port 636 with SSL/TLS)
 * - Certificate validation using domain-specific CA certificates
 * - Secure authentication with read-only LDAP accounts
 * 
 * Architecture:
 * - LDAP Meta: Unified namespace (dc=unified,dc=local) - Aggregation proxy
 * - Backend 1: Passbolt Inc. (dc=passbolt,dc=local) - Historical computing pioneers
 * - Backend 2: Example Corp (dc=example,dc=com) - Modern tech professionals
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
                
                // Return enabled users only
                'enabledUsersOnly' => false,
                
                // Don't use email prefix/suffix (emails are complete)
                'useEmailPrefixSuffix' => false,
                
                // Global user filtering - targets specific groups from both backends
                'userCustomFilters' => '(|(memberof=cn=developers,ou=groups,dc=passbolt,dc=local)(memberof=cn=creative,ou=teams,dc=example,dc=com))',
                
                // Group Object Class for OpenLDAP
                'groupObjectClass' => 'groupOfUniqueNames',
                
                // User Object Class for OpenLDAP  
                'userObjectClass' => 'inetOrgPerson',
                
                // Field mapping for OpenLDAP
                'fieldsMapping' => [
                    'openldap' => [
                        'group' => [
                            'users' => 'uniqueMember'
                        ]
                    ]
                ],
                
                // LDAP Configuration for aggregation setup with LDAPS security
                'ldap' => [
                    'domains' => [
                        // Unified LDAP Meta Backend - Aggregates both directories
                        'unified' => [
                            'domain_name' => 'unified.local',
                            'username' => 'cn=readonly,dc=unified,dc=local',
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
                            
                            'options' => [
                                LDAP_OPT_RESTART => 1,
                                LDAP_OPT_REFERRALS => 0,
                                // LDAPS security options
                                LDAP_OPT_X_TLS_REQUIRE_CERT => LDAP_OPT_X_TLS_NEVER,  // Allow self-signed certificates
                            ],
                            'timeout' => 10,
                        ]
                    ],
                ]
            ]
        ]
    ]
];
