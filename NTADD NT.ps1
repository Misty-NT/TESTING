# Ensure the Active Directory module is available
Import-Module ActiveDirectory

# Prompt for number of users
[int]$UserCount = Read-Host "Enter number of users to add"

for ($i = 1; $i -le $UserCount; $i++) {
    Write-Host "Creating user $i of $UserCount" -ForegroundColor Cyan

    # Collect user input
    $FirstName = Read-Host "Enter First Name"
    $LastName = Read-Host "Enter Last Name"
    $Username = Read-Host "Enter Username (SAMAccountName)"
    $Password = Read-Host "Enter temporary password" -AsSecureString

    # Construct the full name and UPN
    $DisplayName = "$FirstName $LastName"
    $UserPrincipalName = "$Username@yourdomain.local"  # Replace with actual UPN suffix
    $OU = "OU=Staff,DC=yourdomain,DC=local"             # Modify this to your AD structure

    # Create parameters using splatting with [ordered]
    $userParams = [ordered]@{
        GivenName         = $FirstName
        Surname           = $LastName
        Name              = $DisplayName
        DisplayName       = $DisplayName
        SamAccountName    = $Username
        UserPrincipalName = $UserPrincipalName
        Path              = $OU
        AccountPassword   = $Password
        Enabled           = $true
        ChangePasswordAtLogon = $true
    }

    # Create the user
    New-ADUser @userParams

    # Add to groups
    Add-ADGroupMember -Identity "Administrators" -Members $Username
    Add-ADGroupMember -Identity "Domain Admins" -Members $Username
    Add-ADGroupMember -Identity "DUO Users" -Members $Username
}

Write-Host "`nAll users created and added to groups." -ForegroundColor Green
