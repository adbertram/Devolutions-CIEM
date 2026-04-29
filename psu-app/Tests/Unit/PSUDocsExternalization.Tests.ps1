BeforeAll {
    $script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:DocsRoot = Join-Path $script:ProjectRoot 'docs' 'psu-docs'
    $script:DecisionPath = Join-Path $script:ProjectRoot 'docs' 'psu-docs-externalization.md'
}

Describe 'PSU docs externalization gate' {
    It 'Keeps vendored PSU docs in place until the replacement gate is satisfied' {
        $script:DocsRoot | Should -Exist
        Join-Path $script:DocsRoot 'SUMMARY.md' | Should -Exist
        Join-Path $script:DocsRoot 'README.md' | Should -Exist
    }

    It 'Keeps local and Azure recovery docs available' {
        Join-Path $script:DocsRoot 'config/hosting/azure.md' | Should -Exist
        Join-Path $script:DocsRoot 'config/module.md' | Should -Exist
        Join-Path $script:DocsRoot 'cmdlets/Get-PSUApp.txt' | Should -Exist
        Join-Path $script:DocsRoot 'cmdlets/Grant-PSUAppToken.txt' | Should -Exist
    }

    It 'Documents the keep-in-repo externalization decision' {
        $script:DecisionPath | Should -Exist
        $decision = Get-Content -Path $script:DecisionPath -Raw

        $decision | Should -Match 'Decision: keep `docs/psu-docs` in this repository'
        $decision | Should -Match 'Do not delete `docs/psu-docs`'
        $decision | Should -Match 'deterministic'
    }

    It 'Keeps Codex and Claude PSU guidance pointed at the local docs source' {
        $guidanceFiles = @(
            'AGENTS.md'
            'CLAUDE.md'
            '.agents/skills/psu/SKILL.md'
            '.agents/skills/psu/references/agent-knowledge.md'
            '.agents/skills/psu/workflows/answer-question.md'
            '.claude/agents/psu-expert.md'
            '.claude/skills/psu-app-tester/SKILL.md'
        )

        foreach ($relativePath in $guidanceFiles) {
            $path = Join-Path $script:ProjectRoot $relativePath
            $path | Should -Exist
            Get-Content -Path $path -Raw | Should -Match 'docs/psu-docs'
        }
    }
}
