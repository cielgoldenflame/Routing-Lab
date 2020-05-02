$rgname = Read-Host -Prompt "What would you like to be your Resource Group name?`n"
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

$vnetname = Read-Host -Prompt "What will be the name of your VNet?`n"

New-AzVirtualNetwork -AddressPrefix '10.0.0.0/16' -Name $vnetname -Location $rglocation -ResourceGroupName $rgname

$vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rgname

[int]$n = Read-Host -Prompt "How many subnets will there be?`n"
$i = 0
while ($i -lt $n) {
    $subname = Read-Host -Prompt "What will be the name of Subnet $i`n"
    Add-AzVirtualNetworkSubnetConfig -Name $subname -VirtualNetwork $vnet -AddressPrefix "10.0.$i.0/24" | Set-AzVirtualNetwork
    ++$i
}

[int]$vmx = Read-Host -Prompt "How many VMs will you need?`n" 

$vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rgname

while ($o -lt $vmx) {
    
    $vmName = Read-Host -Prompt "What will be the name of VM $o`n"
    
    $version = Read-Host -Prompt "Will VM $o be:`n1 : Server`n2 : Client`n"

    switch ($version) {
        '1' { $publisherName = 'MicrosoftWindowsServer'
            $offerName = 'WindowsServer'
            $skuName = '2016-Datacenter'}
        '2' { $publisherName = 'microsoftwindowsdesktop'
            $offerName = 'windows-10-1809-vhd-client-office-prod-stage'
            $skuName = 'rs5-evd-o365pp'}
    }
    
    $size = Read-Host -Prompt "Please select VM Size`n1 : Standard_D1_v2 (1 CPU 3.5GB RAM)`n2 : Standard_D2_v2 (2 CPU 7GB RAM)`n"
    
    switch ($size) {
        '1' {$vmSize = 'Standard_D1_v2'}
        '2' {$vmSize = 'Standard_D2_v2'}
    }
    
    $adminUsername = 'Student'
    $adminPassword = 'Pa55w.rd1234'
    $adminCreds = New-Object PSCredential $adminUsername, ($adminPassword | ConvertTo-SecureString -AsPlainText -Force)

    $as = Read-Host -Prompt "Will this VM be a part of a Availability Set?`nY/N"

    switch ($as) {
        'Y' {
            $asname = Read-Host -Prompt "What will your availability set be called?`n"
            
            New-AzAvailabilitySet -ResourceGroupName $rgname -Name $asname -Location $rglocation -PlatformUpdateDomainCount "3" -PlatformFaultDomainCount "2"
            
            $availabilitySet = Get-AzAvailabilitySet -ResourceGroupName $rgname -Name $asname 

            $subs = $vnet.Subnets.Name

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
            Set-AzVMOSDisk -VM $vmConfig -Name "$($vmName)_OsDisk_1_$(Get-Random)"  -CreateOption fromImage
            Set-AzVMBootDiagnostic -VM $vmConfig -Disable

            New-AzVM -ResourceGroupName $rgname -Location $rglocation -VM $vmConfig
        }
        'N' {
            $subs = $vnet.Subnets.Name

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
            Set-AzVMOSDisk -VM $vmConfig -Name "$($vmName)_OsDisk_1_$(Get-Random)"  -CreateOption fromImage
            Set-AzVMBootDiagnostic -VM $vmConfig -Disable

            New-AzVM -ResourceGroupName $rgname -Location $rglocation -VM $vmConfig}
    }

++$o
}