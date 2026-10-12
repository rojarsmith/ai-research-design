[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [uri]$Issuer,
    [switch]$AllowLoopbackHttp
)

$ErrorActionPreference = 'Stop'

function Assert-IamUri {
    param([uri]$Value, [string]$Label)
    if (-not $Value.IsAbsoluteUri -or $Value.UserInfo -or $Value.Query -or $Value.Fragment) {
        throw "$Label must be an absolute URI without credentials, query or fragment."
    }
    if ($Value.Scheme -eq 'https') { return }
    if ($AllowLoopbackHttp -and $Value.Scheme -eq 'http' -and $Value.IsLoopback) { return }
    throw "$Label requires HTTPS; HTTP is allowed only for an explicitly enabled loopback lab."
}

Assert-IamUri -Value $Issuer -Label 'Issuer'
$iamExpectedIssuer = $Issuer.AbsoluteUri.TrimEnd('/')
$iamDiscoveryUrl = "$iamExpectedIssuer/.well-known/openid-configuration"
$iamMetadata = Invoke-RestMethod -Uri $iamDiscoveryUrl -TimeoutSec 20 -MaximumRedirection 0
if (-not [string]::Equals([string]$iamMetadata.issuer, $iamExpectedIssuer, [StringComparison]::Ordinal)) {
    throw 'Discovery issuer does not exactly match the expected issuer.'
}

foreach ($iamField in @('authorization_endpoint', 'token_endpoint', 'jwks_uri')) {
    if (-not $iamMetadata.$iamField) { throw "Missing discovery field: $iamField" }
    $iamEndpoint = [uri]$iamMetadata.$iamField
    Assert-IamUri -Value $iamEndpoint -Label $iamField
    if ($iamEndpoint.GetLeftPart([UriPartial]::Authority) -ne $Issuer.GetLeftPart([UriPartial]::Authority)) {
        throw "$iamField is on a different origin. Review the deployment before fetching that endpoint."
    }
}

$iamJwks = Invoke-RestMethod -Uri $iamMetadata.jwks_uri -TimeoutSec 20 -MaximumRedirection 0
if (@($iamJwks.keys).Count -eq 0 -or -not $iamJwks.keys) { throw 'JWKS contains no keys.' }
$iamSigningKeys = @($iamJwks.keys | Where-Object { $_.use -eq 'sig' -or -not $_.use })
if ($iamSigningKeys.Count -eq 0) { throw 'JWKS contains no candidate signing keys.' }
foreach ($iamKey in $iamSigningKeys) {
    if (-not $iamKey.kid -or $iamKey.kty -notin @('RSA', 'EC', 'OKP')) {
        throw 'JWKS contains an unsupported candidate signing key or a key without kid.'
    }
    if ($iamKey.d -or $iamKey.p -or $iamKey.q -or $iamKey.k) { throw 'JWKS unexpectedly contains private or symmetric key material.' }
    if ($iamKey.kty -eq 'RSA' -and (-not $iamKey.n -or -not $iamKey.e)) { throw 'Incomplete RSA public key.' }
    if ($iamKey.kty -eq 'EC' -and (-not $iamKey.crv -or -not $iamKey.x -or -not $iamKey.y)) { throw 'Incomplete EC public key.' }
    if ($iamKey.kty -eq 'OKP' -and (-not $iamKey.crv -or -not $iamKey.x)) { throw 'Incomplete OKP public key.' }
}

[pscustomobject]@{
    Issuer = $iamExpectedIssuer
    DiscoveryReachable = $true
    JwksReachable = $true
    CandidateSigningKeys = $iamSigningKeys.Count
    AdvertisesS256 = @($iamMetadata.code_challenge_methods_supported) -contains 'S256'
    CheckedAtUtc = [DateTime]::UtcNow.ToString('o')
    Scope = 'Endpoint and public-key structure check only; no login, token signature or authorization test.'
}
