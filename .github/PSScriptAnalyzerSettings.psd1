@{
    # PSScriptAnalyzer settings for install_ubuntu_wsl.ps1.
    #
    # That file is a console installer a person pastes into PowerShell, not a
    # reusable module. A few of the default rules are written for modules and are
    # actively wrong here, so they are excluded - with the reason, so nobody has
    # to guess later.

    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Printing to the console is the entire job of this script: it walks a
        # first-time user through enabling WSL. Write-Output would send objects
        # down the pipeline instead of showing progress, and the rule's own
        # suggested alternatives (Write-Verbose, Write-Information) are hidden by
        # default, which would leave the user staring at a blank window.
        'PSAvoidUsingWriteHost',

        # Install-UbuntuWsl is the script's entry point, invoked as
        # `irm ... | iex`. -WhatIf and -Confirm have nowhere to come from in that
        # form, so SupportsShouldProcess would add ceremony and no safety.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
