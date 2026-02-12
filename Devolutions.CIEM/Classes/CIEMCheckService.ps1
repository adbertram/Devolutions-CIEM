class CIEMCheckService {
    [string]$Name
    [string]$Provider

    CIEMCheckService() {}

    CIEMCheckService([string]$Name, [string]$Provider) {
        $this.Name = $Name
        $this.Provider = $Provider
    }

    [string] ToString() {
        return $this.Name
    }
}
