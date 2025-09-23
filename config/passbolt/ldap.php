<?php
/**
 * Passbolt LDAP Aggregation Configuration with STARTTLS Security
 * 
 * This configuration enables secure LDAP directory synchronization using STARTTLS
 * for encrypted connections to multiple LDAP domains. It demonstrates an enterprise
 * merger scenario with two separate LDAP directories.
 * 
 * Security Features:
 * - STARTTLS encryption for all LDAP connections (port 389 with TLS upgrade)
 * - Certificate validation using domain-specific CA certificates
 * - Secure authentication with read-only LDAP accounts
 * 
 * Architecture:
 * - LDAP1: Passbolt Inc. (passbolt.local) - Historical computing pioneers
 * - LDAP2: Example Corp (example.com) - Modern tech professionals
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
                
                // LDAP Configuration for aggregated setup with STARTTLS security
                'ldap' => [
                    'domains' => [
                        // LDAP1: Passbolt Inc. (Historical computing pioneers)
                        // Uses STARTTLS on port 389 with certificate validation
                        'passbolt' => [
                            'domain_name' => 'passbolt.local',
                            'username' => 'cn=readonly,dc=passbolt,dc=local',
                            'password' => 'readonly',
                            'base_dn' => 'dc=passbolt,dc=local',
                            'hosts' => ['ldap1.local'],
                            'use_tls' => true,
                            'port' => 389,
                            'ldap_type' => 'openldap',
                            'lazy_bind' => false,
                            'server_selection' => 'order',
                            'bind_format' => '%username%',
                            'user_path' => 'ou=users',
                            'group_path' => 'ou=groups',
                            'options' => [
                                LDAP_OPT_RESTART => 1,
                                LDAP_OPT_REFERRALS => 0,
                                // STARTTLS security options
                                LDAP_OPT_X_TLS_REQUIRE_CERT => LDAP_OPT_X_TLS_DEMAND,  // Require valid certificates
                                LDAP_OPT_X_TLS_CACERTFILE => '/etc/ssl/certs/ldap1-ca.crt',  // Domain-specific CA
                            ],
                            'timeout' => 10,
                        ],
                        
                        // LDAP2: Example Corp (Modern tech professionals)
                        // Uses STARTTLS on port 389 with certificate validation
                        'example' => [
                            'domain_name' => 'example.com',
                            'username' => 'cn=reader,dc=example,dc=com',
                            'password' => 'reader123',
                            'base_dn' => 'dc=example,dc=com',
                            'hosts' => ['ldap2.local'],
                            'use_tls' => true,
                            'port' => 389,
                            'ldap_type' => 'openldap',
                            'lazy_bind' => false,
                            'server_selection' => 'order',
                            'bind_format' => '%username%',
                            'user_path' => 'ou=people',
                            'group_path' => 'ou=teams',
                            'options' => [
                                LDAP_OPT_RESTART => 1,
                                LDAP_OPT_REFERRALS => 0,
                                // STARTTLS security options
                                LDAP_OPT_X_TLS_REQUIRE_CERT => LDAP_OPT_X_TLS_DEMAND,  // Require valid certificates
                                LDAP_OPT_X_TLS_CACERTFILE => '/etc/ssl/certs/ldap2-ca.crt',  // Domain-specific CA
                            ],
                            'timeout' => 10,
                        ]
                    ],
                ]
            ]
        ]
    ]
];
