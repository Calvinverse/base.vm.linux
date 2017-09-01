Describe 'The firewall' {
    Context 'on the machine' {
        $ufwOutput = & sudo ufw status

        It 'should return a status' {
            $ufwOutput | Should Not Be $null
            $ufwOutput.GetType().FullName | Should Be 'System.Object[]'
            $ufwOutput.Length | Should Be 7
        }

        It 'should be enabled' {
            $ufwOutput[0] | Should Be 'Status: active'
        }

        It 'should allow SSH' {
            ($ufwOutput | Where-Object {$_ -match '(22)\s*(ALLOW)\s*(Anywhere)'} ) | Should Not Be ''
        }
    }
}