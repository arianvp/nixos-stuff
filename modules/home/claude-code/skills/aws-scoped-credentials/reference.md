# GetScopedCredentials reference

Sources: the [API reference](https://docs.aws.amazon.com/STS/latest/APIReference/API_GetScopedCredentials.html)
and the [launch post](https://aws.amazon.com/blogs/security/scope-down-permissions-of-existing-sessions-using-aws-sts-getscopedcredentials/)
(2026-11-20).

## Parameters

At least one of `--policy` or `--duration-seconds` is required.

| Parameter | Limits |
| --- | --- |
| `--policy` | One inline JSON policy of 1 to 2,048 characters. `file://` works. The packed size has its own limit, which causes `PackedPolicyTooLarge`. |
| `--duration-seconds` | 1 to 129,600, and no more than the caller's remaining lifetime. If left out, the caller's expiry is kept. |
| `--scoped-session-description` | 2 to 256 characters. Logged in CloudTrail. |
| `--minimum-session-token-size` | 0 to 4,096 bytes. Pads the token, which is useful for testing consumers that store tokens. |

## Response

- `Credentials`: `AccessKeyId`, `SecretAccessKey`, `SessionToken`, `Expiration`.
- `SessionInfo`: `Arn` and `ScopedSessionId`, the same as the caller's.
- `SourceIdentity`: carried over unchanged.
- `ScopedPoliciesCount`: the number of scope down policies on the session.
  Calls that only shorten the duration don't increase it.
- `SessionTokenSize` and `SessionTokenUtilization`: the token size in bytes,
  and the percentage of the maximum it uses.

## Errors

| Error | Meaning and fix |
| --- | --- |
| `InsufficientSessionLifetime` | `--duration-seconds` exceeds the caller's remaining lifetime. Lower it or leave it out. |
| `InvalidSubjectCredentials` | The caller isn't a valid temporary session, for example IAM user or root keys. Use `aws sts get-session-token` first. |
| `MalformedPolicyDocument` | The policy JSON is invalid. The message says where. |
| `PackedPolicyTooLarge` | The token is too large. Policies and session tags both count. Shrink the policy and watch `SessionTokenUtilization`. |
| `AccessDenied` | `sts:GetScopedCredentials` isn't allowed, or an earlier scope down policy doesn't allow it. |
| Unknown command or operation | The AWS CLI is older than 2.42.0. |

## Access control

`sts:GetScopedCredentials` can be allowed or denied in every policy type.
`sts:DurationSeconds` limits the duration, and global condition keys such as
`aws:PrincipalArn`, `aws:PrincipalTag` and `aws:SourceVpce` limit who can call
it and from where.

## Limits

- 200 requests per second per account per Region.
- Available in all commercial, GovCloud and China Regions, but not on the STS
  global endpoint.
- A few AWS services don't accept scoped credentials. If a call fails
  unexpectedly, check the IAM User Guide's list of unsupported services.
