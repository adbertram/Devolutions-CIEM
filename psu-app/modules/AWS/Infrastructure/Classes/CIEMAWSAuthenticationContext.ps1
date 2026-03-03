class CIEMAWSAuthenticationContext : CIEMAuthenticationContext {
    [string]$Region

    CIEMAWSAuthenticationContext() {
        $this.Provider = 'AWS'
    }
}

class CIEMAWSCurrentProfileAuthenticationContext : CIEMAWSAuthenticationContext {
    [string]$Profile

    CIEMAWSCurrentProfileAuthenticationContext() {
        $this.Method = 'CurrentProfile'
    }
}

class CIEMAWSAccessKeyAuthenticationContext : CIEMAWSAuthenticationContext {
    [bool]$HasAccessKeyId      # true when key exists in PSU secret store
    [bool]$HasSecretAccessKey  # true when key exists in PSU secret store

    CIEMAWSAccessKeyAuthenticationContext() {
        $this.Method = 'AccessKey'
    }
}
