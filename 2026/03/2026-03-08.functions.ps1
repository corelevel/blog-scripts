function New-DeploymentReport {
	<#
	.SYNOPSIS
		Compares two scripts directories for a given database and generates:
		- A migration script
		- An HTML differences report

	.DESCRIPTION
		Generates a SQL migration script and HTML differences report using SQL Compare
		Switches - https://documentation.red-gate.com/sc/using-the-command-line/switches-used-in-the-command-line
		Options - https://documentation.red-gate.com/sc/using-the-command-line/options-used-in-the-command-line
		Exit codes - https://documentation.red-gate.com/sc/using-the-command-line/exit-codes-used-in-the-command-line

		Add "NoTransactions" option to remove transactions from the deployment SQL scripts
		For example, transactions are not supported when the deployment includes memory-optimized objects

	.PARAMETER SqlCompareExecutable
		Path to SQL Compare executable

	.PARAMETER DatabaseName
		Name of the database.

	.PARAMETER SourceDirectory
		Source scripts root directory

	.PARAMETER TargetDirectory
		Target scripts root directory

	.PARAMETER Options
		Comparison options

	.PARAMETER OutputDirectory
		Output directory for generated report and SQL script
	#>

	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path $_ -PathType Leaf })]
		[string]$SqlCompareExecutable,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$DatabaseName,

		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path $_ -PathType Container })]
		[string]$SourceDirectory,

		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path $_ -PathType Container })]
		[string]$TargetDirectory,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Options = "Default",

		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path $_ -PathType Container })]
		[string]$OutputDirectory
	)

	Set-StrictMode -Version Latest

	# Defining "Databases identical" exit code
	$ExitCodeIdentical = 63

	try {
		$timeStamp = (Get-Date).ToString('yyyy-MM-dd.HH-mm')
		$sourcePath = Join-Path $SourceDirectory $DatabaseName
		$targetPath = Join-Path $TargetDirectory $DatabaseName
		$outputPath = Join-Path $OutputDirectory $DatabaseName
		$reportFile = Join-Path $outputPath "$timeStamp.html"
		$scriptFile = Join-Path $outputPath "$timeStamp.sql"

		if (-not (Test-Path $sourcePath -PathType Container)) {
			throw "Source path not found: $sourcePath"
		}

		if (-not (Test-Path $targetPath -PathType Container)) {
			throw "Target path not found: $targetPath"
		}

		$result = [PSCustomObject]@{
				SourcePath = $sourcePath
				TargetPath = $targetPath
				ReportPath = $reportFile
				ScriptPath = $scriptFile
				Options = $Options
				ExitCode = 0
				Success = $true
				Timestamp = $timeStamp
			}

		Write-Verbose "SourcePath: $sourcePath"
		Write-Verbose "TargetPath: $targetPath"
		Write-Verbose "Options: $Options"

		if ($PSCmdlet.ShouldProcess($DatabaseName, "Compare '$sourcePath' with '$targetPath'")) {
			if (-not (Test-Path $outputPath -PathType Container)) {
				New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
				Write-Verbose "Created output directory: $outputPath"
			}

			$arguments = @(
				"/Scripts1:`"$sourcePath`""
				"/Scripts2:`"$targetPath`""
				"/Report:`"$reportFile`""
				"/ScriptFile:`"$scriptFile`""
				"/ReportType:Html"
				"/ReportAllObjectsWithDifferences"
				"/Force"
				"/Quiet"
				"/Options:$Options"
			)

			Write-Verbose "Starting SQL Compare..."

			$process = Start-Process `
				-FilePath $SqlCompareExecutable `
				-ArgumentList $arguments `
				-Wait `
				-PassThru `
				-NoNewWindow

			switch ($process.ExitCode) {
				0 { Write-Verbose "Differences found" }
				$ExitCodeIdentical { Write-Verbose "Databases are identical" }
				default { throw "SQL Compare failed. Exit code: $($process.ExitCode)" }
			}

			$result.ExitCode = $process.ExitCode
			$result.Success = $process.ExitCode -in @(0, $ExitCodeIdentical)
		}
		$result
	}
	catch {
		Write-Error "Failed to generate deployment report: $_"
		throw
	}
}