class CIEMCheckService {
    [string]$Name
    [CIEMCloudProvider]$CloudProvider

    CIEMCheckService() {}

    CIEMCheckService([string]$Name, [CIEMCloudProvider]$CloudProvider) {
        $this.Name = $Name
        $this.CloudProvider = $CloudProvider
    }

    [string] ToString() {
        return $this.Name
    }
}
