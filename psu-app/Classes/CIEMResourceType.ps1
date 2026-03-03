class CIEMResourceType {
    [string]$Name              # "KeyVault", "S3Bucket", etc.
    [string]$DisplayName       # "Key Vault", "S3 Bucket", etc.
    [string]$Provider          # "Azure", "AWS"
    [string]$ServiceName       # Link to CIEMProviderService.Name (e.g., "Storage", "S3")

    CIEMResourceType() {}

    [string] ToString() { return $this.Name }
}

class CIEMAzureResourceType : CIEMResourceType {
    [string]$ArmProviderPrefix # "Microsoft.KeyVault/vaults", etc. (null for Subscription)

    CIEMAzureResourceType() { $this.Provider = 'Azure' }
}

class CIEMAWSResourceType : CIEMResourceType {
    [string]$ArnServicePrefix  # "s3", "ec2", "iam", etc.

    CIEMAWSResourceType() { $this.Provider = 'AWS' }
}
