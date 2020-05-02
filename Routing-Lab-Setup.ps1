$scriptdir = Split-Path $Script:MyInvocation.MyCommand.Path

$rgname = Read-Host -Prompt "What would you like to be your Resource Group name?`n"
Clear-Host
$x = Read-Host -Prompt "Where would you like your Resource Group located?

1 : Central US
2 : East US
3 : East US 2
4 : West US
5 : North Central US
6 : South Central US`n"

switch ($x) {
    "1" {$rglocation = 'centralus'}
    '2' {$rglocation = 'eastus'}
    '3' {$rglocation = 'eastus2'}
    '4' {$rglocation = 'westus'}
    '5' {$rglocation = 'northcentralus'}
    '6' {$rglocation = 'southcentralus'}
    Default {$rglocation = 'eastus2'}
}

New-AzResourceGroup -Name $rgname -Location $rglocation

Clear-Host

$vnetname = Read-Host -Prompt "What will be the name of your VNet?`n"

New-AzVirtualNetwork -AddressPrefix '10.0.0.0/16' -Name $vnetname -Location $rglocation -ResourceGroupName $rgname

$vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rgname

Clear-Host

[int]$n = Read-Host -Prompt "How many subnets will there be?`n"
$i = 0
while ($i -lt $n) {
    Clear-Host

    $subname = Read-Host -Prompt "What will be the name of Subnet $i`n"
    Add-AzVirtualNetworkSubnetConfig -Name $subname -VirtualNetwork $vnet -AddressPrefix "10.0.$i.0/24" | Set-AzVirtualNetwork
    ++$i
}

Clear-Host

$asname = Read-Host -Prompt "What will your availability set be called?`n"

New-AzAvailabilitySet -ResourceGroupName $rgname -Name $asname -Location $rglocation -PlatformUpdateDomainCount "3" -PlatformFaultDomainCount "2" -Sku Aligned

Clear-Host

[int]$vmx = Read-Host -Prompt "How many VMs will you need?`n" 

$vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rgname

$o = 0
while ($o -lt $vmx) {

    Clear-Host

    $vmName = Read-Host -Prompt "What will be the name of VM $o`n"

    Clear-Host

    $version = Read-Host -Prompt "Will VM $o be:`n1 : Server`n2 : Client`n"

    switch ($version) {
        '1' {   $publisherName = 'MicrosoftWindowsServer'
                $offerName = 'WindowsServer'
                $skuName = '2016-Datacenter'}
        '2' {   $publisherName = 'MicrosoftWindowsDesktop'
                $offerName = 'Windows-10'
                $skuName = 'rs5-pro'}
    }
    
    Clear-Host

    $size = Read-Host -Prompt "Please select VM Size`n1 : Standard_DS1_v2 (1 CPU 3.5GB RAM)`n2 : Standard_DS2_v2 (2 CPU 7GB RAM)`n"
    
    switch ($size) {
        '1' {$vmSize = 'Standard_DS1_v2'}
        '2' {$vmSize = 'Standard_DS2_v2'}
    }
    
    $adminUsername = 'Student'
    $adminPassword = 'Pa55w.rd1234'
    $adminCreds = New-Object PSCredential $adminUsername, ($adminPassword | ConvertTo-SecureString -AsPlainText -Force)

    Clear-Host

    $as = Read-Host -Prompt "Will this VM be a part of a Availability Set?`nY/N"

    switch ($as) {
        'Y' {
            $availabilitySet = Get-AzAvailabilitySet -ResourceGroupName $rgname -Name $asname 

            $subs = $vnet.Subnets.Name

            Clear-Host

            $subnet = Read-Host "What subnet will this VM be attached to?`n$subs`n"
            
            $subnetid = (Get-AzVirtualNetworkSubnetConfig -Name $subnet -VirtualNetwork $vnet).Id

            $rdpRule = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
            $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rgname -Location $rglocation -Name "$vmName-nsg" -SecurityRules $rdpRule
            $pip = New-AzPublicIpAddress -Name "$vmName-ip" -ResourceGroupName $rgname -Location $rglocation -AllocationMethod Dynamic
            $nic = New-AzNetworkInterface -Name "$($vmName)$(Get-Random)" -ResourceGroupName $rgname -Location $rglocation -SubnetId $subnetid -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

            $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $availabilitySet.Id
            Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
            Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $adminCreds
            Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version 'latest'
            Set-AzVMOSDisk -VM $vmConfig -Name "$($vmName)_OsDisk_1_$(Get-Random)" -StorageAccountType Premium_LRS -CreateOption fromImage
            Set-AzVMBootDiagnostic -VM $vmConfig -Disable

            New-AzVM -ResourceGroupName $rgname -Location $rglocation -VM $vmConfig -AsJob
        }
        'N' {
            $subs = $vnet.Subnets.Name

            Clear-Host

            $subnet = Read-Host "What subnet will this VM be attached to?`n$subs`n"
            
            $subnetid = (Get-AzVirtualNetworkSubnetConfig -Name $subnet -VirtualNetwork $vnet).Id

            $rdpRule = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
            $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rgname -Location $rglocation -Name "$vmName-nsg" -SecurityRules $rdpRule
            $pip = New-AzPublicIpAddress -Name "$vmName-ip" -ResourceGroupName $rgname -Location $rglocation -AllocationMethod Dynamic
            $nic = New-AzNetworkInterface -Name "$($vmName)$(Get-Random)" -ResourceGroupName $rgname -Location $rglocation -SubnetId $subnetid -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

            $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
            Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
            Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $adminCreds
            Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version 'latest'
            Set-AzVMOSDisk -VM $vmConfig -Name "$($vmName)_OsDisk_1_$(Get-Random)" -StorageAccountType Premium_LRS -CreateOption fromImage
            Set-AzVMBootDiagnostic -VM $vmConfig -Disable

            New-AzVM -ResourceGroupName $rgname -Location $rglocation -VM $vmConfig -AsJob} 
    }

++$o
}

Clear-Host

$job = (Get-Job -Newest 1).Id

Wait-Job -Id $job

$rt = Read-Host -Prompt "Would you like to create your Route Table here?`nY\N`n"

switch ($rt) {
    'N' {}
    'Y' {
        Clear-Host

        $rtname = Read-Host -Prompt "what will be the name of your Route Table?`n"

        Clear-Host

        $rname = Read-Host -Prompt "What will be the name of your Route?`n"

        $subs = $vnet.Subnets.Name

        Clear-Host

        $d = Read-Host "What subnet will be the destination?`n$subs`n"
        
        $dest = (Get-AzVirtualNetworkSubnetConfig -Name $d -VirtualNetwork $vnet).AddressPrefix

        $vms = (Get-AzVM -ResourceGroupName $rgname).Name

        Clear-Host

        $hname = Read-Host -Prompt "Which VM will act as the hop?`n$vms`n"

        $nic = (Get-AzNetworkInterface -ResourceGroupName $rgname -Name "$hname*")
            $nic.EnableIPForwarding = $true
            Set-AzNetworkInterface -NetworkInterface $nic -AsJob
            Invoke-AzVMRunCommand -ResourceGroupName $rgname -VMName $hname -CommandId 'RunPowerShellScript' -ScriptPath "$scriptdir\install-router.ps1"
            Restart-AzVM -ResourceGroupName $rgname -Name $hname -AsJob

        $hopip = $nic.IpConfigurations.privateipaddress
    
        $Route = New-AzRouteConfig -Name $rname -AddressPrefix "$dest" -NextHopType VirtualAppliance -NextHopIpAddress $hopip

        New-AzRouteTable -Name $rtname -ResourceGroupName $rgname -Location $rglocation -Route $Route

        Clear-Host

        [int]$rtsublinknum = Read-Host -Prompt "How many subnets will be added to the route table?`n"

        $p = 0
        while ($p -lt $rtsublinknum) {
            
            $subs = $vnet.Subnets.Name

            Clear-Host
            
            $sname = Read-Host -Prompt "What is the name of the $($p+1) subnet to link?`n$subs`n"
            
            $ap = (Get-AzVirtualNetworkSubnetConfig -Name $sname -VirtualNetwork $vnet).AddressPrefix

            $routetable = Get-AzRouteTable -ResourceGroupName $rgname -Name $rtname

            Set-AzVirtualNetworkSubnetConfig -Name $sname -VirtualNetwork $vnet -RouteTable $routetable -AddressPrefix $ap | Set-AzVirtualNetwork
           
            $p++
        }
    }
}

Clear-Host

$lbq = Read-Host -Prompt "Would you like to configure your Load Balancer here?`nY\N`n"

switch ($lbq) {
    'N' {}
    'Y' {}
}

Clear-Host

$dnsq = Read-Host -Prompt "Would you like to configure a Private DNS Zone?`nY\N`n"

switch ($dnsq) {
    'N' {}
    'Y' {
        Clear-Host
        $pdzname = Read-Host -Prompt "What will be the name of your Private DNS Zone?`nNote: Please use proper naming context (i.e. name.com)`n"

        New-AzPrivateDnsZone -Name "$pdzname" -ResourceGroupName $rgname 

        $linkname = Read-Host -Prompt "what will be the name of the VNet Link?"
        New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rgname -ZoneName "$pdzname" -Name $linkname -VirtualNetworkId $vnet.Id -EnableRegistration

        switch ($lbq) {
            'N' {}
            'Y' {$lbarec = Read-Host -Prompt 'What would you like as the name of the "A" record for your Load Balancer'
                $lbip = (Get-AzLoadBalancer -ResourceGroupName $rgname -Name $lbname)#############
                New-AzPrivateDnsRecordSet -ResourceGroupName $rgname -Name $lbarec -RecordType A -Ttl 3600 -ZoneName "$pdzname" -PrivateDnsRecord (New-AzPrivateDnsRecordConfig -Ipv4Address $lbip)
            }
        }
        
    }
}

Invoke-AzVMRunCommand