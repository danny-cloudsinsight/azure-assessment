# Custom validation rules for Entra ID

# Synopsis: Number of global administrators should be less than 5
Rule 'Custom.Entra.MaxGlobalAdmins' -Ref 'Cust-Entra-001' -Level Error -Type 'entra/directoryroles' -If { $TargetObject.DisplayName -eq 'Global Administrator' } {
    $Assert.Less($TargetObject, 'NumberOfMembers', 5).
    Reason("Number of global administrators is {0}.", $TargetObject.NumberOfMembers)
}

# Synopsis: Number of global administrators should be more than 1
Rule 'Custom.Entra.MinGlobalAdmins' -Ref 'Cust-Entra-002' -Level Error -Type 'entra/directoryroles' -If { $TargetObject.DisplayName -eq 'Global Administrator' } {
    $Assert.Greater($TargetObject, 'NumberOfMembers', 1).
    Reason("Number of global administrators is {0}.", $TargetObject.NumberOfMembers)
}

# Synopsis: App registrations should have a valid secret
Rule 'Custom.Entra.AppRegSecrets' -Ref 'Cust-Entra-003' -Level Error -Type 'entra/appregistrations' -If { $TargetObject.PasswordCredentials.count -gt 0} {
    $secretExpiryWarningDays = 30
    $currentDate = Get-Date
    $expiryWarningDate = (Get-Date).AddDays($secretExpiryWarningDays)
    $expiryStatus = "None"
    foreach ($password in $TargetObject.PasswordCredentials) {
        # Calculate correct status in case of multiple secrets
        if ($password.EndDate -gt $expiryWarningDate) {
            # If at least one secret is valid, return pass
            return $Assert.Pass()
        }
        elseif ($password.EndDate -gt $currentDate) {
            if ($expiryStatus -ne "OK") { 
                $expiryStatus = "Expiring"
                $endDate = $password.EndDate
            }
        }
        else {
            if ($expiryStatus -eq "None") {
                $expiryStatus = "Expired"
                $endDate = $password.EndDate
            }
        }
    }
    return $Assert.Fail("App registration has no valid secrets. Status: {0}. Date: {1}", $expiryStatus,$endDate )
}   

# Synopsis: Identity Secure Score recommendations should not be active.
Rule 'Custom.Entra.IdentitySecureScore' -Ref 'Cust-Entra-004' -Level Error -Type 'identitySecureScore', 'identityBestPractice'  {
    $Assert.NotIn($TargetObject, 'Status', @('active')).
    Reason("{0} - Priority: {1} - Score: ({2}/{3})", $TargetObject.DisplayName, $TargetObject.Priority, $TargetObject.CurrentScore, $TargetObject.MaxScore)
}

Rule 'Custom.Entra.UnverifiedDomains' -Ref 'Cust-Entra-005' -Type 'entra/generalInfo' -Level Error  {
    $Assert.NullOrEmpty($TargetObject, '"Other domains"').
    Reason("Following domains are not verified: {0}", $TargetObject.'Other domains')
}