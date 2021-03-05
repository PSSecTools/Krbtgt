# Changelog

## 1.1.11 (2021-03-05)

- Fix: Sync-KrbAccount - LDAP-based replication fails on new objects, reversed replication command direction

## 1.1.10 (2021-01-12)

- Upd: Test-KrbPasswordReset - added explicit replication of canary account to reduce failure due to ad object not found
- Fix: Test-KrbPasswordReset - cleaned up result object and filled DCFailed
- Fix: Reset-KrbPassword - cleaned up error reporting

## 1.1.7 (2020-09-08)

- Upd: All commands - New single item replication option: LDAP (instead of WinRM). LDAP new default
- Upd: Get-KrbAccount - added "Credential" parameter
- Upd: Reset-KrbPassword - added "Credential" parameter
- Upd: Reset-KrbRODCPassword - added "Credential" parameter
- Upd: Sync-KrbAccount - added "Credential" parameter
- Upd: Test-KrbPasswordReset - added "Credential" parameter

## 1.0.1 (2019-07-15)

- Fix: Test-KrbPasswordReset is not automatically picking up DCs if none were specified
- Fix: Test-KrbPasswordReset ignores explicitly specified list of DCs

## 1.0.0 (2019-04-05)

- New: Initial Release
