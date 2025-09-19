<?php
/**
 * Passbolt LDAP Aggregation Configuration
 * Configures directory sync for OpenLDAP meta backend aggregation
 * Demonstrates enterprise merger scenario with two LDAP directories
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
                
                // LDAP Configuration for aggregated setup
                'ldap' => [
                    'domains' => [
                        // LDAP1: Passbolt Inc. (Historical computing pioneers)
                        'passbolt' => [
                            'domain_name' => 'passbolt.local',
                            'username' => 'cn=readonly,dc=passbolt,dc=local',
                            'password' => 'readonly',
                            'base_dn' => 'dc=passbolt,dc=local',
                            'hosts' => ['ldap1.local'],
                            'use_tls' => false,
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
                            ],
                            'timeout' => 10,
                        ],
                        
                        // LDAP2: Example Corp (Modern tech professionals)
                        'example' => [
                            'domain_name' => 'example.com',
                            'username' => 'cn=reader,dc=example,dc=com',
                            'password' => 'reader123',
                            'base_dn' => 'dc=example,dc=com',
                            'hosts' => ['ldap2.local'],
                            'use_tls' => false,
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
                            ],
                            'timeout' => 10,
                        ]
                    ],
                ]
            ]
        ]
    ]
];
