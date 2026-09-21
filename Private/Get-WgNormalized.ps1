# ======================================================================
# A port of winget's NormalizationVersion::Initial name and publisher
# normaliser, from src/AppInstallerCommonCore/NameNormalization.cpp.
#
# The values in the winget source index's norm_names2 and norm_publishers2
# are produced by this algorithm applied to case-folded input. Reproducing
# it lets us correlate an installed ARP entry to a winget package exactly
# as winget does, instead of guessing with name heuristics.
#
# Validated against winget's own 1137-row test corpus.
# ======================================================================

$Script:RxOpt = [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant, Compiled'
function New-Rx { param([string]$P) [regex]::new($P, $Script:RxOpt) }

# ICU applies UREGEX_CASE_INSENSITIVE, which case-CLOSES character classes,
# so \p{Lu} also matches lowercase. .NET's IgnoreCase does not do that, so
# every \p{Lu} below is written out as [\p{Lu}\p{Ll}\p{Lt}]. \p{L} would be
# wrong: it adds \p{Lo} (CJK, Hebrew, Arabic), which ICU's closure does not.
$LU = '[\p{Lu}\p{Ll}\p{Lt}]'

# --- architecture (NameNormalization.cpp:243-247) ---------------------
$Script:RxArch32Or64 = New-Rx '(?<=^|[^\p{L}\p{Nd}])((64[\\\/]32|32[\\\/]64)[\p{Pd}\p{Pc}\p{Z}]?BIT)S?(?:\sEDITION)?'
$Script:RxArchX64    = New-Rx '(?<=^|[^\p{L}\p{Nd}])(X64|AMD64|X86([\p{Pd}\p{Pc}]64))(?=\P{Nd}|$)(?:\sEDITION)?'
$Script:RxArch64Bit  = New-Rx '(?<=^|[^\p{L}\p{Nd}])(64[\p{Pd}\p{Pc}\p{Z}]?BIT)S?(?:\sEDITION)?'
$Script:RxArchX32    = New-Rx '(?<=^|[^\p{L}\p{Nd}])(X32|X86)(?=\P{Nd}|$)(?:\sEDITION)?'
$Script:RxArch32Bit  = New-Rx '(?<=^|[^\p{L}\p{Nd}])(32[\p{Pd}\p{Pc}\p{Z}]?BIT)S?(?:\sEDITION)?'

# --- locale / SAP / KB (:250, :253, KB at :387) -----------------------
# Both [A-Z] lookarounds become [A-Za-z] as well as the \p{Lu} rewrite.
# Without both, "… - en-us" never matches and the Office case fails.
$Script:RxLocale = New-Rx ("(?<![A-Za-z])((?:$LU{2,3}(-(CANS|CYRL|LATN|MONG))?-$LU{2})(?![A-Za-z])(?:-VALENCIA)?)")
$Script:RxSAP    = New-Rx ("^(?:[$($LU.Trim('[',']'))\p{Nd}]+[\._])+[$($LU.Trim('[',']'))\p{Nd}]+(?:-(?:\p{Nd}+\.)+\p{Nd}+)(?:-(?:$LU{2}(?:_$LU{2})?|CORE))(?:-(?:$LU{2}|\p{Nd}{2}))$")
$Script:RxKB     = New-Rx '\((KB\d+)\)'

# --- the 17 name patterns, in order (:284-303) ------------------------
$Script:NameRx = @(
    '(?<=^ROBLOX\s(PLAYER|STUDIO))(\sFOR\s.*)'
    '(?<=^BOMGAR\s(JUMP CLIENT|(ACCESS|REPRESENTATIVE) CONSOLE|BUTTON)|^EMBEDDED CALLBACK)(\s.*)'
    '^\(.*?\)'
    '(\(\s*\)|\[\s*\]|"\s*")'
    '\(CHANGE #\d{1,2} TO [CDEF]:\\(.+?\\)*[^\s]*\\?\)'
    '\([CDEF]:\\(.+?\\)*[^\s]*\\?\)'
    '"[CDEF]:\\(.+?\\)*[^\s]*\\?"'
    '((INSTALLED\sAT|IN)\s)?[CDEF]:\\(.+?\\)*[^\s]*\\?'
    ("(?<!\p{L})(?:(?:V|VER|VERSI(?:O|Ó)N|VERSÃO|VERSIE|WERSJA|BUILD|RELEASE|RC|SP)\P{L})?$LU\p{Nd}+(?:[\p{Po}\p{Pd}\p{Pc}]\p{Nd}+)+")
    '((?<!\p{L})(?:V|VER|VERSI(?:O|Ó)N|VERSÃO|VERSIE|WERSJA|BUILD|RELEASE|RC|SP)\P{L}?)?\p{Nd}+([\p{Po}\p{Pd}\p{Pc}]\p{Nd}?(RC|B|A|R|SP|K)?\p{Nd}+)+([\p{Po}\p{Pd}\p{Pc}]?[\p{L}\p{Nd}]+)*'
    '(FOR\s)?(?<!\p{L})(?:P|V|R|VER|VERSI(?:O|Ó)N|VERSÃO|VERSIE|WERSJA|BUILD|RELEASE|RC|SP)(?:\P{L}|\P{L}\p{L})?(\p{Nd}|\.\p{Nd})+(?:RC|B|A|R|V|SP)?\p{Nd}?'
    '\sEN\s*$'
    '\([^\(\)]*\)|\[[^\[\]]*\]'
    '(?:\p{Ps}.*\p{Pe}|".*")'
    '(?<!\p{L})(?:http[s]?|ftp):\/\/'
    '^[^\p{L}\p{Nd}]+'
    '[^\p{L}\p{Nd}]+$'
) | ForEach-Object { New-Rx $_ }

# --- publisher patterns, in order (:305-315) --------------------------
$Script:PubRx = @(
    '((?<!\p{L})(?:V|VER|VERSI(?:O|Ó)N|VERSÃO|VERSIE|WERSJA|BUILD|RELEASE|RC|SP)\P{L}?)?\p{Nd}+([\p{Po}\p{Pd}\p{Pc}]\p{Nd}?(RC|B|A|R|SP|K)?\p{Nd}+)+([\p{Po}\p{Pd}\p{Pc}]?[\p{L}\p{Nd}]+)*'
    '(FOR\s)?(?<!\p{L})(?:P|V|R|VER|VERSI(?:O|Ó)N|VERSÃO|VERSIE|WERSJA|BUILD|RELEASE|RC|SP)(?:\P{L}|\P{L}\p{L})?(\p{Nd}|\.\p{Nd})+(?:RC|B|A|R|V|SP)?\p{Nd}?'
    '\([^\(\)]*\)|\[[^\[\]]*\]'
    '(?:\p{Ps}.*\p{Pe}|".*")'
    '(?<!\p{L})(?:http[s]?|ftp):\/\/'
    '(?<=^|\s)[^\p{L}]+(?=\s|$)'
    '\P{L}+$'
    '(?:(?<=^\p{L})|(?<=\P{L}\p{L}))(\.|\/)(?=\p{L}(?:\P{L}|$))'
) | ForEach-Object { New-Rx $_ }

$Script:RxSplitName = New-Rx '([^\p{L}\p{Nd}\+\&])'
$Script:RxSplitPub  = New-Rx '([^\p{L}\p{Nd}])'
$Script:RxStrip     = New-Rx '[^\p{L}\p{Nd}]'

# Extracted verbatim from winget's NameNormalization.cpp: LocaleViews
# (:313-341, 210 entries) and LegalEntitySuffixViews (:348-355, 45 entries
# / 44 distinct after folding). Both folded to lower case, compared as
# whole tokens with ordinal equality.
$Script:LocaleList = @(
    'af-za', 'am-et', 'ar-ae', 'ar-bh', 'ar-dz', 'ar-eg', 'ar-iq', 'ar-jo',
    'ar-kw', 'ar-lb', 'ar-ly', 'ar-ma', 'ar-om', 'ar-qa', 'ar-sa', 'ar-sy',
    'ar-tn', 'ar-ye', 'arn-cl', 'as-in', 'az-cyrl-az', 'az-latn-az', 'ba-ru', 'be-by',
    'bg-bg', 'bn-bd', 'bn-in', 'bo-cn', 'br-fr', 'bs-cyrl-ba', 'bs-latn-ba', 'ca-es',
    'ca-es-valencia', 'co-fr', 'cs-cz', 'cy-gb', 'da-dk', 'de-at', 'de-ch', 'de-de',
    'de-li', 'de-lu', 'dsb-de', 'dv-mv', 'el-gr', 'en-au', 'en-bz', 'en-ca',
    'en-gb', 'en-ie', 'en-in', 'en-jm', 'en-my', 'en-nz', 'en-ph', 'en-sg',
    'en-tt', 'en-us', 'en-za', 'en-zw', 'es-ar', 'es-bo', 'es-cl', 'es-co',
    'es-cr', 'es-do', 'es-ec', 'es-es', 'es-gt', 'es-hn', 'es-mx', 'es-ni',
    'es-pa', 'es-pe', 'es-pr', 'es-py', 'es-sv', 'es-us', 'es-uy', 'es-ve',
    'et-ee', 'eu-es', 'fa-ir', 'fi-fi', 'fil-ph', 'fo-fo', 'fr-be', 'fr-ca',
    'fr-ch', 'fr-fr', 'fr-lu', 'fr-mc', 'fy-nl', 'ga-ie', 'gd-db', 'gl-es',
    'gsw-fr', 'gu-in', 'ha-latn-ng', 'he-il', 'hi-in', 'hr-ba', 'hr-hr', 'hsb-de',
    'hu-hu', 'hy-am', 'id-id', 'ig-ng', 'ii-cn', 'is-is', 'it-ch', 'it-it',
    'iu-cans-ca', 'iu-latn-ca', 'ja-jp', 'ka-ge', 'kk-kz', 'kl-gl', 'km-kh', 'kn-in',
    'ko-kr', 'kok-in', 'ky-kg', 'lb-lu', 'lo-la', 'lt-lt', 'lv-lv', 'mi-nz',
    'mk-mk', 'ml-in', 'mn-mn', 'mn-mong-cn', 'moh-ca', 'mr-in', 'ms-bn', 'ms-my',
    'mt-mt', 'nb-no', 'ne-np', 'nl-be', 'nl-nl', 'nn-no', 'nso-za', 'oc-fr',
    'or-in', 'pa-in', 'pl-pl', 'prs-af', 'ps-af', 'pt-br', 'pt-pt', 'qut-gt',
    'quz-bo', 'quz-ec', 'quz-pe', 'rm-ch', 'ro-ro', 'ru-ru', 'rw-rw', 'sa-in',
    'sah-ru', 'se-fi', 'se-no', 'se-se', 'si-lk', 'sk-sk', 'sl-si', 'sma-no',
    'sma-se', 'smj-no', 'smj-se', 'smn-fi', 'sms-fi', 'sq-al', 'sr-cyrl-ba', 'sr-cyrl-cs',
    'sr-cyrl-me', 'sr-cyrl-rs', 'sr-latn-ba', 'sr-latn-cs', 'sr-latn-me', 'sr-latn-rs', 'sv-fi', 'sv-se',
    'sw-ke', 'syr-sy', 'ta-in', 'te-in', 'tg-cyrl-tj', 'th-th', 'tk-tm', 'tn-za',
    'tr-tr', 'tt-ru', 'tzm-latn-dz', 'ug-cn', 'uk-ua', 'ur-pk', 'uz-cyrl-uz', 'uz-latn-uz',
    'vi-vn', 'wo-sn', 'xh-za', 'yo-ng', 'zh-cn', 'zh-hk', 'zh-mo', 'zh-sg',
    'zh-tw', 'zu-za'
)
$Script:SuffixList = @(
    'ab', 'ad', 'ag', 'aps', 'as', 'asa', 'bv', 'co', 'company', 'corp',
    'corporation', 'cv', 'doo', 'ev', 'ges', 'gesmbh', 'gmbh', 'holding', 'holdings', 'inc',
    'incorporated', 'kg', 'ks', 'limited', 'llc', 'lp', 'ltd', 'ltda', 'mbh', 'nv',
    'plc', 'ps', 'pty', 'pvt', 'sa', 'sarl', 'sc', 'sca', 'sl', 'sp',
    'spa', 'srl', 'sro', 'subsidiary'
)

$Script:Locales  = [Collections.Generic.HashSet[string]]::new([string[]]$Script:LocaleList, [StringComparer]::Ordinal)
$Script:Suffixes = [Collections.Generic.HashSet[string]]::new([string[]]$Script:SuffixList, [StringComparer]::Ordinal)

# AICLI_SPACE_CHARS - deliberately NOT .NET's default whitespace set,
# which is a superset and diverges on U+2028/U+2029/U+0085.
$Script:SpaceChars = [char[]]@(' ', "`f", "`n", "`r", "`t", [char]0x0B)
function Test-WgBlank { param([string]$S)
    if ([string]::IsNullOrEmpty($S)) { return $true }
    foreach ($c in $S.ToCharArray()) { if ($Script:SpaceChars -notcontains $c) { return $false } }
    return $true
}

function Invoke-WgPrelude {
    param([string]$S)
    if ($null -eq $S) { return '' }
    $S = $S.ToLowerInvariant()                                   # S1 (approximates ICU fold)
    $S = $S.Normalize([Text.NormalizationForm]::FormKC)          # S2
    $S = $S.Trim($Script:SpaceChars)                             # S3
    if ($S.Length -ge 3) {                                       # S4
        $i = $S.IndexOf('@@', 3)
        if ($i -ge 0) { $S = $S.Substring(0, $i) }
    }
    while ($S.Length -ge 2 -and (                                # S5
            ($S[0] -eq '"' -and $S[-1] -eq '"') -or
            ($S[0] -eq '(' -and $S[-1] -eq ')'))) {
        $S = $S.Substring(1, $S.Length - 2)
    }
    return $S
}

function Remove-WgLocale {
    # Rebuild the string, dropping only spans that are a known locale.
    # A match that is not in the list is copied out verbatim (:142).
    param([string]$S)
    $out = [Text.StringBuilder]::new()
    $pos = 0
    foreach ($m in $Script:RxLocale.Matches($S)) {
        [void]$out.Append($S.Substring($pos, $m.Index - $pos))
        if (-not $Script:Locales.Contains($m.Value)) { [void]$out.Append($m.Value) }
        $pos = $m.Index + $m.Length
    }
    [void]$out.Append($S.Substring($pos))
    return $out.ToString()
}

function Invoke-WgLoop {
    # Repeat the ORDERED pass to a fixed point - not each pattern to a
    # fixed point in turn (RemoveAll, :107-117).
    param([string]$S, [regex[]]$Patterns)
    do {
        $changed = $false
        foreach ($re in $Patterns) {
            $n = $re.Replace($S, '')
            if ($n -ne $S) { $changed = $true; $S = $n }
        }
    } while ($changed)
    return $S
}

function Join-WgTokens {
    param([string]$S, [regex]$Splitter, [switch]$StopOnExclusion)
    $tokens = [Collections.Generic.List[string]]::new()
    foreach ($piece in $Splitter.Split($S)) {
        if (Test-WgBlank $piece) { continue }
        # The first token found is never dropped, whatever it is (:197).
        if ($tokens.Count -gt 0 -and $Script:Suffixes.Contains($piece)) {
            if ($StopOnExclusion) { break } else { continue }
        }
        $tokens.Add($piece)
    }
    return $Script:RxStrip.Replace(($tokens -join ''), '')
}

function Get-WgNormalizedName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Name)

    $s = Invoke-WgPrelude $Name

    # N1: SAP packages exit before any stripping - dots and underscores
    # survive into norm_names2 (:378).
    if ($Script:RxSAP.IsMatch($s)) {
        return [pscustomobject]@{ Name = $s; Architecture = 'Unknown' }
    }

    # N2: short-circuiting chain. 32/64 first (superstring of 64), then
    # 64 before 32 (x86-64 is a superstring of x86) (:84-104).
    $arch = 'Unknown'
    $t = $Script:RxArch32Or64.Replace($s, '')
    if ($t -ne $s) { $s = $t }
    else {
        $t = $Script:RxArchX64.Replace($s, '')
        if ($t -ne $s) { $s = $t; $arch = 'X64' }
        else {
            $t = $Script:RxArch64Bit.Replace($s, '')
            if ($t -ne $s) { $s = $t; $arch = 'X64' }
            else {
                $t = $Script:RxArchX32.Replace($s, '')
                if ($t -ne $s) { $s = $t; $arch = 'X86' }
                else {
                    $t = $Script:RxArch32Bit.Replace($s, '')
                    if ($t -ne $s) { $s = $t; $arch = 'X86' }
                }
            }
        }
    }

    $s = Remove-WgLocale $s                        # N3
    $s = $Script:RxKB.Replace($s, '$1')            # N4 - before the bracket strippers
    $s = Invoke-WgLoop $s $Script:NameRx           # N5
    $s = Join-WgTokens $s $Script:RxSplitName      # N6 + N7

    return [pscustomobject]@{ Name = $s; Architecture = $arch }
}

function Get-WgNormalizedPublisher {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Publisher)

    $s = Invoke-WgPrelude $Publisher
    $s = Invoke-WgLoop $s $Script:PubRx
    # stopOnExclusion: a legal-entity suffix TERMINATES the publisher (:418).
    return (Join-WgTokens $s $Script:RxSplitPub -StopOnExclusion)
}

function Get-WgNameWithArchitecture {
    # How the arch-suffixed row is stored: lowercase base, uppercase suffix.
    param([Parameter(Mandatory)]$Normalized)
    if ($Normalized.Architecture -eq 'Unknown') { return $Normalized.Name }
    return ('{0}({1})' -f $Normalized.Name, $Normalized.Architecture)
}
