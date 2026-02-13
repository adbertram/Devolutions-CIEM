class CIEMProviderService {
    [string]$Name
    [string]$Provider

    CIEMProviderService() {}

    CIEMProviderService([string]$Name, [string]$Provider) {
        $this.Name = $Name
        $this.Provider = $Provider
    }

    [string] ToString() {
        return $this.Name
    }
}
