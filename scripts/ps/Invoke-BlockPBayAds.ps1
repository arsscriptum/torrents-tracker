function Add-FirewallRuleForHosts {
    param (
        [string[]]$Hosts
    )

    foreach ($srv in $Hosts) {
        # Create a firewall rule for outgoing traffic
        New-NetFirewallRule -DisplayName "Piratebay-Ads Block Outbound $srv" -Direction Outbound -Action Block -RemoteAddress "$srv" -Enabled True

        # Create a firewall rule for incoming traffic
        New-NetFirewallRule -DisplayName "Piratebay-Ads Block Inbound $srv" -Direction Inbound -Action Block -RemoteAddress "$srv" -Enabled True
    }
}

# List of hosts to block
$hostsToBlock = @(
    ## torrindex.net has style cheats, you way want to keep it
    #"torrindex.net",    
    "assets.bwbx.io",
    "bwbx.io",
    "securepubads.g.doubleclick.net",
    "g.doubleclick.net",
    "doubleclick.net",
    "vi.ml314.com",
    "ml314.com",
    "onautcatholi.xyz",
    "exdynsrv.com",
    "ricewaterhou.xyz",
    "js.wpadmngr.com",
    "italarizege.xyz",
    "abservinean.com",
    "a.exdynsrv.com",
    "a.exosrv.com",
    "cdn.engine.spotscenered.info",
    "syndication.exdynsrv.com",
    "d1n3aexzs37q4s.cloudfront.net",
    "iconcardinal.com",
    "cipledecline.buzz",
    "www.viled.cfd"
)

# Call the function to block the listed hosts
Add-FirewallRuleForHosts -Hosts $hostsToBlock
